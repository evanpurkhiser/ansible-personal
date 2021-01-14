# -*- coding: utf-8 -*-

import hassapi as hass
import typing
from datetime import datetime, timedelta
from random import randint
from pathlib import Path

import parsedatetime
from human_dates import time_ago_in_words
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, scoped_session, relationship
from sqlalchemy.orm.exc import NoResultFound
from sqlalchemy import (
    create_engine,
    Column,
    Integer,
    String,
    DateTime,
    ColumnDefault,
    ForeignKey,
    or_,
)

from utils import time_ago


class TelegramMessage(typing.TypedDict):
    user_id: str
    from_first: str
    from_last: str
    chat_id: str
    command: str
    args: typing.List[str]


Base = declarative_base()


class UsageHistory(Base):
    __tablename__ = "usage_history"

    id = Column(Integer, primary_key=True)
    access_code_id = Column(Integer, ForeignKey("access_code.id"))
    access_code = relationship("AccessCode", back_populates="usage_history")
    created_at = Column(DateTime, default=datetime.utcnow)


class AccessCode(Base):
    __tablename__ = "access_code"

    id = Column(Integer, primary_key=True)
    name = Column(String)
    code = Column(String, nullable=False, unique=True)
    expires_at = Column(DateTime, ColumnDefault(None))
    created_at = Column(DateTime, default=datetime.utcnow)

    usage_history = relationship(
        "UsageHistory",
        back_populates="access_code",
        cascade="all,delete",
        order_by=UsageHistory.created_at.desc(),
    )


msg_help = """
📞 Control the callbox for 2421 16th.

*/callbox register [name]* - Add a permanent access code
*/callbox singleuse [expires after]* - Add a temporary access code
*/callbox codes* - List active access codes
*/callbox remove [code]* - Remove an existing access code
"""

# Default to 4 hours for the single use access codes
DEFAULT_SINGLE_USER_DURATION = timedelta(hours=4)

# The number of digits to generate
ACCESS_CODE_LEN = 5


class Callbox(hass.Hass):
    def initialize(self):
        self.listen_event(self.handle_telegram, event="telegram_command")
        self.register_endpoint(self.handle_door_call, name="callbox_trigger")
        self.register_endpoint(self.handle_door_auth, name="callbox_auth")

        db_path = Path(self.config_dir) / "callbox.db"
        engine = create_engine(
            f"sqlite:///{db_path}", connect_args={"check_same_thread": False}
        )

        Base.metadata.create_all(engine)

        Session = scoped_session(sessionmaker(bind=engine))
        self.db = Session()

    def send_msg(self, msg, **kwargs):
        self.call_service("telegram_bot/send_message", message=msg, **kwargs)

    def generate_code(self):
        """
        Generates a unique access code.

        Will not produce codes that have already been generated or codes that
        were created less than two months ago.
        """
        while True:
            code = "".join(
                ["{}".format(randint(0, 9)) for _ in range(0, ACCESS_CODE_LEN)]
            )

            is_used = (
                self.db.query(AccessCode)
                .filter(
                    AccessCode.code == code,
                    AccessCode.expires_at < datetime.now() - timedelta(weeks=8),
                )
                .count()
                > 0
            )

            if not is_used:
                break
        return code

    def get_active_codes(self):
        return (
            self.db.query(AccessCode)
            .filter(
                or_(
                    AccessCode.expires_at == None,
                    AccessCode.expires_at > datetime.now(),
                )
            )
            .order_by(AccessCode.expires_at.asc())
        )

    def handle_telegram(self, _, msg: TelegramMessage, *args):
        if not msg["command"].startswith("/callbox"):
            return

        args = msg["args"]

        if not args:
            self.send_msg(msg_help)
            return

        action = args.pop(0)

        # Creation of permanent codes
        if action in ("register", "add", "new"):
            code = self.generate_code()
            name = args.pop(0) if len(args) > 0 else None

            self.db.add(AccessCode(code=code, name=name))
            self.db.commit()

            if name:
                self.send_msg(f"The access code `{code}` has been set for {name}.",)
            else:
                self.send_msg(f"The access code `{code}` has been added.",)
            return

        # Creation of temporary codes
        if action in ("singleuse", "ephemeral"):
            code = self.generate_code()
            expires_str = " ".join(args)

            parser = parsedatetime.Calendar()

            # Get now as the parsedatetime struct
            now_struct, _ = parser.parse("")
            now = datetime(*now_struct[:6])

            # Parse input text
            dt_struct, status = parser.parse(expires_str)

            # status 0 indicates we failed to parse a time
            if status == 0:
                expires = now + DEFAULT_SINGLE_USER_DURATION
            else:
                expires = datetime(*dt_struct[:6])

            if expires <= now:
                self.send_msg("Expiration time must be in the future!")
                return

            self.db.add(AccessCode(code=code, expires_at=expires))
            self.db.commit()

            delta = expires - now
            hours = delta.total_seconds() // 3600
            expire_time = f"{hours} hours"

            self.send_msg(f"The access code `{code}` will expire in `{expire_time}`")
            return

        # Listing of codes
        if action in ("codes", "list", "ls"):
            items = self.get_active_codes()
            text = []

            for i in items:
                if i.expires_at is not None:
                    time_left = i.expires_at - datetime.now()
                    hours = round(time_left.total_seconds() / 3600, 1)
                    expiry = f"{hours} hours remaining"
                else:
                    expiry = "no expiration"

                name = i.name or ("[anon]" if i.expires_at is None else "[single use]")
                text.append(f"- `{i.code}`: *{name}* with {expiry}")

            if len(text) == 0:
                self.send_msg("Callbox does not have any registered codes",)
                return

            text = "\n".join(text)
            reply = f"Active access codes:\n\n{text}"
            self.send_msg(reply)
            return

        # Removing of codes
        if action in ("remove", "rm"):
            try:
                code = args.pop(0)
            except IndexError:
                codes = self.get_active_codes()

                if codes.count() == 0:
                    self.send_msg("Callbox does not have any registered codes",)
                    return

                self.send_msg(
                    "What access code should I remove?",
                    keyboard=[f"/callbox remove {c.code}" for c in codes],
                )
                return

            try:
                ac = self.db.query(AccessCode).filter(AccessCode.code == code).one()
            except NoResultFound:
                self.send_msg(
                    f"`{code}` is not registered", keyboard=[],
                )
                return

            self.db.delete(ac)
            self.db.commit()

            self.send_msg(
                "Access code removed!", keyboard=[],
            )
            return

        # No valid command provided
        self.send_msg(msg_help)

    def handle_door_call(self, data):
        num_codes = self.get_active_codes().count()
        num_single_use = (
            self.get_active_codes().filter(AccessCode.expires_at != None).count()
        )

        resp = {
            "numDigits": ACCESS_CODE_LEN,
            "numRegisteredCodes": num_codes - num_single_use,
            "numSingleUseCodes": num_single_use,
        }

        return resp, 200

    def handle_door_auth(self, data):
        try_code = data["code"]
        try:
            ac = self.get_active_codes().filter(AccessCode.code == try_code).one()
        except NoResultFound:
            self.send_msg(
                f"🔓 Callbox: *Invalid code used* - code entered was `{try_code}`."
            )
            # TODO: Log denied attempts
            return {"status": "denied"}, 200

        resp = {
            "status": "granted",
            "name": ac.name,
            "visitNumber": len(ac.usage_history) + 1,
            "isSingleUse": ac.expires_at is not None,
            "lastVisit": None,
        }

        if len(ac.usage_history) > 0:
            last_visit = ac.usage_history[0]
            resp["lastVisit"] = time_ago(last_visit.created_at)

        if ac.expires_at is not None:
            self.send_msg(
                f"🔓 Callbox: One time use code `{ac.code}` has been used.\n*DOOR UNLOCKED*"
            )
            self.db.delete(ac)
        else:
            # TODO: Send these messages to specific users
            self.send_msg(f"🔓 Callbox: Door unlocked for *{ac.name or '[anon]'}*")
            self.db.add(UsageHistory(access_code=ac))
        self.db.commit()

        return resp, 200
