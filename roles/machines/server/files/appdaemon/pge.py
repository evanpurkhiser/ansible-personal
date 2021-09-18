# -*- coding: utf-8 -*-
import hassapi as hass

import urllib.parse
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Tuple, TypedDict, List
from pathlib import Path
import itertools
import colorsys
import base64
from io import BytesIO

from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, scoped_session
from sqlalchemy import (
    exc,
    create_engine,
    Column,
    Integer,
    DateTime,
)

from matplotlib.colors import ColorConverter
import matplotlib.pyplot as plt
import matplotlib.ticker as plticker

import parsedatetime
import pytz
import requests
from bs4 import BeautifulSoup
from dateutil import parser


# XXX: Note that the path here is mounted on both the AD and HASS
# docker images. So they 'share' a filesystem, which is why the two
# paths here are the same
CHART_PATH = "/var/lib/hass-ad/pge-usage-chart.png"


class TelegramMessage(TypedDict):
    user_id: str
    from_first: str
    from_last: str
    chat_id: str
    command: str
    args: List[str]


tz = pytz.timezone("America/Los_Angeles")

Base = declarative_base()


class BillingHistory(Base):
    __tablename__ = "usage_history"

    id = Column(Integer, primary_key=True)
    start = Column(DateTime, index=True, unique=True)
    end = Column(DateTime)
    total = Column(Integer)


msg_help = """
🔌 Query PG&E power usage for the apartment

*/pge lastbill* - Show previous bill and usage graph
*/pge current* - Show the current billing period usage
*/pge [date]* - Show usage from a particular day
"""

new_bill_msg = """
💡 *New PG&E Bill*

📅 *Period:* {start} → {end}
🏷 *Total:* ${total_cost:1.2f}
💸 [Venmo ${split_cost:1.2f} to Evan](https://venmo.com/EvanPurkhiser?txn=pay&note={venmo_note}&amount={split_cost:1.2f})
"""

basic_usage_msg = """
📅 *Period:* {start} → {end}
🏷 *Total:* ${total_cost:1.2f} (${split_cost:1.2f} split)
"""


class PGEApi:
    # Common headers to look like a browser
    common_headers = {
        "User-Agent": "Mozilla/5.0",
    }

    def __init__(self, username, password):
        self.username = username
        self.password = password

        self.account = None

        self.session = requests.Session()

    def ensure_authorized(self):
        self.do_login()
        self.do_saml_auth()

    def do_login(self):
        auth = ":".join([self.username, self.password]).encode("utf8")

        resp = self.session.get(
            "https://apigprd.cloud.pge.com/myaccount/v1/login",
            headers=dict(
                Authorization=f"Basic {base64.b64encode(auth).decode('utf8')}",
                **self.common_headers,
            ),
        )
        resp.raise_for_status()
        return resp.json()["user"]

    def do_saml_auth(self):
        # start SAML auth (Origin pge.com)
        resp = self.session.get(
            "https://itiamping.cloud.pge.com/idp/startSSO.ping",
            headers=self.common_headers,
            params={
                "PartnerSpId": "sso.opower.com",
                "TargetResource": "https://pge.opower.com/ei/app/r/energy-usage-details",
            },
        )
        resp.raise_for_status()

        # Recieve SAML response
        soup = BeautifulSoup(resp.content, "html.parser")
        url = soup.select_one("form[action]")["action"]
        body = {el["name"]: el["value"] for el in soup.select("input[name]")}

        resp = self.session.post(url, headers=self.common_headers, data=body)
        resp.raise_for_status()

        # Continue back to PGE
        soup = BeautifulSoup(resp.content, "html.parser")
        url = soup.select_one("form[action]")["action"]
        body = {el["name"]: el["value"] for el in soup.select("input[name]")}

        resp = self.session.post(url, headers=self.common_headers, data=body)
        resp.raise_for_status()

    def get_account(self, address: str):
        resp = self.session.get(
            "https://apigprd.cloud.pge.com/myaccount/v1/cocaccount/secure/account/retrieveMyEnergyAccounts",
            params={"userId": self.username},
            headers=self.common_headers,
        )
        resp.raise_for_status()
        user_info = resp.json()

        return next(
            acct
            for acct in user_info["accounts"]
            if acct["accountAddress"]["addressLine1"] == "2421 16TH ST UNIT 301"
        )

    def get_billing_info(self, account):
        resp = self.session.post(
            "https://apigprd.cloud.pge.com/myaccount/v1/cocbillpay/secure/getBillSummary",
            headers=self.common_headers,
            json={
                "accountId": f"{account['accountNumber']}-3",
                "accountNumber": "",
                "action": "BILL_SUMMARY",
                "pendingPaymentsUI": 0,
                "accountRuleMessages": [],
                "globalSync": False,
            },
        )
        resp.raise_for_status()
        return resp.json()

    def get_usage(
        self, start_date: datetime, end_date: datetime, aggregate="day", utility="ELEC"
    ):
        opowerCustomer = self.session.get(
            "https://pge.opower.com/ei/edge/apis/multi-account-v1/cws/pge/customers/current",
            headers=self.common_headers,
        )
        opowerCustomer = opowerCustomer.json()

        # Get GAS and ELEC utility accounts
        utilities = {
            utility["meterType"]: utility
            for utility in opowerCustomer["utilityAccounts"]
        }

        resp = self.session.get(
            f"https://pge.opower.com/ei/edge/apis/DataBrowser-v1/cws/cost/utilityAccount/{utilities[utility]['uuid']}",
            headers=self.common_headers,
            params={
                "startDate": start_date.isoformat(),
                "endDate": end_date.isoformat(),
                "aggregateType": aggregate,
                "includePtr": False,
            },
        )
        return resp.json()


def scale_lightness(rgb, scale_l):
    h, l, s = colorsys.rgb_to_hls(*rgb)
    return colorsys.hls_to_rgb(h, min(1, l * scale_l), s=s)


def get_billing_start_end(billing_info):
    bill_start = datetime.fromtimestamp(
        int(billing_info["billSummary"]["billStatementStartDate"]) // 1000, tz
    )
    bill_end = datetime.fromtimestamp(
        int(billing_info["billSummary"]["billStatementEndDate"]) // 1000, tz
    )

    return bill_start, bill_end


def generate_chart(usage, aggregate="day"):
    DAY_PEAK = "ON_PEAK"
    DAY_OFF_PEAK = "OFF_PEAK"
    day_parts = [DAY_OFF_PEAK, DAY_PEAK]

    day_part_labels = {DAY_PEAK: "peak usage", DAY_OFF_PEAK: "off-peak usage"}

    all_reads = itertools.chain(*(r["readComponents"] for r in usage["reads"]))
    tier_numbers = set(c["tierNumber"] for c in all_reads)
    tier_numbers = sorted(tier_numbers)

    # Tier colors are hard coded.. might need ot add more tiers if things fail
    tier_colors = [
        "#2594CC",
        "#F7BE1C",
        "#F71C54",
    ]

    bar_configs = [
        (tier_numbers[i], day_parts[j])
        for i in range(len(tier_numbers))
        for j in range(len(day_parts))
    ]

    @dataclass
    class Bar:
        tier: int
        day_part: str
        label: str
        values: list[float]
        bottoms: list[float]
        color: Tuple[float, float, float]

    bars: List[Bar] = []

    # Build values for each bar component
    for config in bar_configs:
        tier, day_part = config
        values: List[float] = []

        for read in usage["reads"]:
            try:
                component = next(
                    c
                    for c in read["readComponents"]
                    if c["tierNumber"] == tier and c["dayPart"] == day_part
                )
                values.append(component["cost"])
            except StopIteration:
                values.append(0)

        # Compute previous sums for the bottom offset of the stacked bar
        if len(bars) > 0:
            bottoms = [float(sum(vals)) for vals in zip(*(bar.values for bar in bars))]
        else:
            bottoms = [0.0] * len(values)

        # Grab colors for each tier. Off peak is the lighter color
        color = tier_colors[tier - 1]
        color = ColorConverter.to_rgb(color)

        if day_part == DAY_OFF_PEAK:
            color = scale_lightness(color, 1.5)

        bar = Bar(
            tier=tier,
            day_part=day_part,
            values=values,
            bottoms=bottoms,
            color=color,
            label=f"Tier {tier} ({day_part_labels[day_part]})",
        )

        bars.append(bar)

    agg_fmt = {
        "day": "%m/%d",
        "hour": "%H",
    }

    dates = [parser.parse(read["startTime"]) for read in usage["reads"]]
    labels = [dt.strftime(agg_fmt[aggregate]) for dt in dates]
    totals = [read["providedCost"] for read in usage["reads"]]

    fig, ax = plt.subplots(figsize=(14, 5), tight_layout=True)

    main_color = "#353B48"

    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_color(main_color)
    ax.spines["bottom"].set_color(main_color)

    ax.tick_params(axis="x", colors=main_color)
    ax.tick_params(axis="y", colors=main_color)

    ax.xaxis.label.set_color(main_color)

    # Spread out the labels for days
    if aggregate == "day":
        ax.xaxis.set_major_locator(plticker.MultipleLocator(base=6.0))

    ax.yaxis.label.set_color(main_color)
    ax.yaxis.set_major_formatter("${x:1.2f}")
    ax.yaxis.grid(color="#DCDDE1", linestyle="dashed")

    ax.set_axisbelow(True)
    ax.margins(x=0.015, tight=True)

    bar_containers = []

    for bar in bars:
        b1 = ax.bar(
            x=labels,
            width=0.8,
            bottom=bar.bottoms,
            height=bar.values,
            label=bar.label,
            color=bar.color,
        )
        bar_containers.append(b1)

    if len(bar_containers) > 0:
        ax.bar_label(
            bar_containers[-1],
            labels=["${x:1.2f}".format(x=t) for t in totals],
            rotation_mode="anchor",
            fontsize=7,
            fontweight="bold",
            padding=3,
        )

    ax.legend(
        loc="lower left",
        ncol=len(tier_numbers) * len(day_parts),
        frameon=False,
        bbox_to_anchor=(0, -0.15),
    )

    fig.subplots_adjust(bottom=0.2)

    fig.savefig(fname=CHART_PATH, format="png")


def get_tomorrow_time(hour=18):
    dtnow = datetime.now()

    if dtnow.hour < 6:
        dt = datetime(dtnow.year, dtnow.month, dtnow.day, hour, 0, 0, 0)
    else:
        tomorrow = dtnow + timedelta(days=1)
        dt = datetime(tomorrow.year, tomorrow.month, tomorrow.day, 6, 0, 0, 0)

    return dt


class PGE(hass.Hass):
    def initialize(self):
        self.listen_event(self.handle_telegram, event="telegram_command")

        db_path = Path(self.config_dir) / "pge.db"
        engine = create_engine(
            f"sqlite:///{db_path}", connect_args={"check_same_thread": False}
        )

        Base.metadata.create_all(engine)

        # Database connection
        Session = scoped_session(sessionmaker(bind=engine))
        self.db = Session()

        self.api = PGEApi(self.args["pge_username"], self.args["pge_password"])

        # Immediately check for a new bill
        self.check_for_new_bill()

    def check_for_new_bill(self):
        self.api.ensure_authorized()

        account = self.api.get_account(self.args["account_address"])
        billing_info = self.api.get_billing_info(account)

        bill_start, bill_end = get_billing_start_end(billing_info)
        total_cost = float(billing_info["billSummary"]["currentAmountDue"])

        # If it's already in there we'll have an error
        try:
            self.db.add(
                BillingHistory(start=bill_start, end=bill_end, total=total_cost)
            )
            self.db.commit()
            self.notify_new_bill(billing_info)
        except exc.IntegrityError:
            self.db.rollback()
            # Nothing to do if it's not a new bill
            pass

        # Run again tomorrow at 6pm
        tomorrow = get_tomorrow_time(18)
        tomorrow_delta = tomorrow - datetime.now()
        self.run_in(self.check_for_new_bill, tomorrow_delta.total_seconds())

    def send_msg(self, msg, **kwargs):
        self.call_service("telegram_bot/send_message", message=msg, **kwargs)

    def send_photo(self, file, **kwargs):
        self.call_service("telegram_bot/send_photo", file=file, **kwargs)

    def notify_new_bill(self, billing_info):
        account = self.api.get_account(self.args["account_address"])
        billing_info = self.api.get_billing_info(account)

        # Get the last billing preiod
        bill_start, bill_end = get_billing_start_end(billing_info)
        total_cost = float(billing_info["billSummary"]["currentAmountDue"])

        usage = self.api.get_usage(bill_start, bill_end)

        start = bill_start.strftime("%b %d")
        end = bill_end.strftime("%b %d")

        generate_chart(usage)
        self.send_photo(
            CHART_PATH,
            caption=new_bill_msg.format(
                start=start,
                end=end,
                total_cost=total_cost,
                split_cost=total_cost / 2,
                venmo_note=urllib.parse.quote_plus(f"PG&E Bill Split ({start})"),
            ),
        )

    def handle_telegram(self, _, msg: TelegramMessage, *args):
        if not msg["command"].startswith("/pge"):
            return

        args = msg["args"]

        if not args:
            self.send_msg(msg_help)
            return

        action = args.pop(0)

        # Ensure our API client is authorized
        self.api.ensure_authorized()

        # Current billing period
        if action == "current":
            last_bill = (
                self.db.query(BillingHistory)
                .order_by(BillingHistory.start.desc())
                .first()
            )

            last_bill_end = last_bill.end
            now = datetime.now(tz=tz)

            usage = self.api.get_usage(last_bill_end, now)
            total_cost = sum(read["providedCost"] for read in usage["reads"])

            generate_chart(usage)
            self.send_photo(
                CHART_PATH,
                caption=basic_usage_msg.format(
                    start=last_bill_end.strftime("%b %d"),
                    end=now.strftime("%b %d"),
                    total_cost=total_cost,
                    split_cost=total_cost / 2,
                ),
            )

        # Most recent billing period
        elif action == "lastbill":
            account = self.api.get_account(self.args["account_address"])
            billing_info = self.api.get_billing_info(account)

            # Get the last billing preiod
            bill_start, bill_end = get_billing_start_end(billing_info)
            total_cost = float(billing_info["billSummary"]["currentAmountDue"])

            # Query usage for the billing period
            usage = self.api.get_usage(bill_start, bill_end)

            generate_chart(usage)
            self.send_photo(
                CHART_PATH,
                caption=basic_usage_msg.format(
                    start=bill_start.strftime("%b %d"),
                    end=bill_end.strftime("%b %d"),
                    total_cost=total_cost,
                    split_cost=total_cost / 2,
                ),
            )

        # Usage from a specific day
        else:
            parser = parsedatetime.Calendar()

            # Get now as the parsedatetime struct
            dt_struct, status = parser.parse(" ".join([action] + args))

            if status == 0:
                self.send_msg("I don't undestand that date")
                return

            parsed_date = datetime(*dt_struct[:6], tzinfo=tz)

            target_start = parsed_date.replace(hour=0, minute=0, second=0)
            target_end = parsed_date.replace(hour=23, minute=59, second=59)

            # Query usage for the billing period
            usage = self.api.get_usage(target_start, target_end, aggregate="hour")
            total_cost = sum(read["providedCost"] for read in usage["reads"])

            date = target_start.strftime("%B %d %Y")

            generate_chart(usage, aggregate="hour")
            self.send_photo(CHART_PATH, caption=f"🗓 Daily usage on *{date}*")
