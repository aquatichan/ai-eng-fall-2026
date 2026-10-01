import datetime
import json
import os
import time

# focus_log.json lives in the same folder as this program
LOG_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "focus_log.json")

MENU = """
1. Start a focus session
2. Show today's summary
3. Quit
"""


def load_log():
    """Return the list of saved sessions; empty list if the file doesn't exist."""
    try:
        with open(LOG_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return []


def save_log(sessions):
    """Write the full list of sessions back to focus_log.json."""
    with open(LOG_PATH, "w", encoding="utf-8") as f:
        json.dump(sessions, f, indent=2)


def record_session(sessions):
    """Ask for a name, time the session until Enter, then append and save it."""
    name = ""
    while not name:
        name = input("Session name: ").strip()
        if not name:
            print("Please enter a name.")

    start = time.monotonic()
    input("Timing started. Press Enter when you're done.")
    elapsed_seconds = time.monotonic() - start

    minutes = round(elapsed_seconds / 60, 1)
    sessions.append({
        "name": name,
        "date": datetime.date.today().isoformat(),
        "minutes": minutes,
    })
    save_log(sessions)
    print(f"Saved: {name}, {minutes} min ({elapsed_seconds:.1f} sec)")


def print_summary(sessions):
    """Print per-name totals and a grand total for a list of session dicts."""
    if not sessions:
        print("No focus sessions logged today.")
        return

    totals = {}  # name -> total minutes (keeps first-seen order)
    for s in sessions:
        totals[s["name"]] = totals.get(s["name"], 0) + s["minutes"]

    for name, minutes in totals.items():
        print(f"{name}: {minutes:.1f} min")

    print(f"Total: {sum(totals.values()):.1f} min")


def main():
    sessions = load_log()
    while True:
        print(MENU)
        choice = input("Choose an option: ").strip()

        if choice == "1":
            record_session(sessions)
        elif choice == "2":
            today = datetime.date.today().isoformat()
            print_summary([x for x in sessions if x["date"] == today])
        elif choice == "3":
            print("Goodbye!")
            break
        else:
            print("Not a valid choice")


if __name__ == "__main__":
    main()