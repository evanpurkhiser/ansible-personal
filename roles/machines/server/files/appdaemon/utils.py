from datetime import datetime


DAY_INCREMENTS = [
    [365, "year"],
    [30, "month"],
    [7, "week"],
    [1, "day"],
]

SECOND_INCREMENTS = [
    [3600, "hour"],
    [60, "minute"],
    [1, "second"],
]


def time_ago(dt):
    diff = datetime.utcnow() - dt
    if diff.days < 0:
        return "just now"
    for increment, label in DAY_INCREMENTS:
        if diff.days >= increment:
            increment_diff = int(diff.days / increment)
            return str(increment_diff) + " " + label + plural(increment_diff) + " ago"
    for increment, label in SECOND_INCREMENTS:
        if diff.seconds >= increment:
            increment_diff = int(diff.seconds / increment)
            return str(increment_diff) + " " + label + plural(increment_diff) + " ago"
    return "just now"


def plural(num):
    if num != 1:
        return "s"
    return ""
