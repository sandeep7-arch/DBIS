import tkinter as tk
from tkinter import ttk, messagebox
import mysql.connector



DB = dict(host="localhost", user="cpsapp", password="cps123", database="CPSDB")


VIEWS = {
    "Departments": "SELECT * FROM DEPARTMENT",
    "Students": "SELECT * FROM STUDENT",
    "Skills": "SELECT * FROM SKILL",
    "Companies": "SELECT * FROM COMPANY",
    "Job postings": "SELECT * FROM JOB_POSTING",
    "Online assessments": "SELECT * FROM ONLINE_ASSESSMENT",
    "OA results": """SELECT r.OA_ID, o.OA_Name, r.Student_ID, s.Name AS Student,
                            r.Score, o.Passing_Score, IF(r.Is_Passed, 'Pass', 'Fail') AS Outcome
                     FROM OA_RESULT r
                     JOIN ONLINE_ASSESSMENT o ON o.OA_ID = r.OA_ID
                     JOIN STUDENT s ON s.Student_ID = r.Student_ID""",
    "Recruitment rounds": "SELECT * FROM RECRUITMENT_ROUND",
    "Applications": """SELECT a.Application_ID, s.Name AS Student, j.Job_Title, c.Company_Name,
                              a.Applied_Date, a.Current_Status
                       FROM APPLICATION a
                       JOIN STUDENT s ON s.Student_ID = a.Student_ID
                       JOIN JOB_POSTING j ON j.Job_ID = a.Job_ID
                       JOIN COMPANY c ON c.Company_ID = j.Company_ID
                       ORDER BY a.Application_ID""",
    "Results": "SELECT * FROM RESULT",
    "Offers": """SELECT o.Offer_ID, o.Application_ID, s.Name AS Student, c.Company_Name,
                        o.Offered_CTC, o.Offer_Date, o.Expected_Joining_Date, o.Offer_Status
                 FROM PLACEMENT_OFFER o
                 JOIN APPLICATION a ON a.Application_ID = o.Application_ID
                 JOIN STUDENT s ON s.Student_ID = a.Student_ID
                 JOIN JOB_POSTING j ON j.Job_ID = a.Job_ID
                 JOIN COMPANY c ON c.Company_ID = j.Company_ID
                 ORDER BY o.Offer_ID""",
}



def query(sql, params=None):
    conn = mysql.connector.connect(**DB)
    cur = conn.cursor()
    cur.execute(sql, params or ())
    cols = [d[0] for d in cur.description]
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return cols, rows


def call_proc(name, args):
    conn = mysql.connector.connect(**DB)
    cur = conn.cursor()
    try:
        return cur.callproc(name, args)
    finally:
        cur.close()
        conn.close()


def run(name, args, ok_message):
    """Call a stored procedure and show success or the error message."""
    try:
        result = call_proc(name, args)
        messagebox.showinfo("Done", ok_message(result))
        refresh()
    except mysql.connector.Error as e:
        messagebox.showerror("Error", e.msg)
    except ValueError:
        messagebox.showerror("Error", "Please check the values entered.")



root = tk.Tk()
root.title("Campus Placement System")
root.geometry("900x500")
tabs = ttk.Notebook(root)
tabs.pack(fill="both", expand=True, padx=5, pady=5)


def make_form(parent, fields, button_text, action):
    """fields: list of labels. Returns nothing; action(values_list) is called on click."""
    frame = ttk.Frame(parent, padding=15)
    entries = []
    for i, label in enumerate(fields):
        ttk.Label(frame, text=label).grid(row=i, column=0, sticky="w", pady=3)
        e = ttk.Entry(frame, width=30)
        e.grid(row=i, column=1, pady=3, padx=10)
        entries.append(e)
    ttk.Button(frame, text=button_text,
               command=lambda: action([e.get().strip() for e in entries])
               ).grid(row=len(fields), column=0, columnspan=2, pady=10)
    return frame


PAGE = 100
state = {"cols": [], "offset": 0, "total": 0, "sort": None, "desc": False,
         "loading": False, "done": False}

browse = ttk.Frame(tabs, padding=5)
tabs.add(browse, text="Browse")

top = ttk.Frame(browse)
top.pack(fill="x", pady=(0, 5))
choice = ttk.Combobox(top, values=list(VIEWS), state="readonly", width=20)
choice.set("Applications")
choice.pack(side="left")
ttk.Label(top, text="Search in").pack(side="left", padx=(15, 4))
field = ttk.Combobox(top, values=["All columns"], state="readonly", width=18)
field.current(0)
field.pack(side="left")
search_var = tk.StringVar()
search_entry = ttk.Entry(top, textvariable=search_var, width=30)
search_entry.pack(side="left", padx=6)

status = ttk.Label(browse, anchor="w")
status.pack(side="bottom", fill="x")
tree = ttk.Treeview(browse, show="headings")
vbar = ttk.Scrollbar(browse, command=tree.yview)
hbar = ttk.Scrollbar(browse, orient="horizontal", command=tree.xview)
tree.tag_configure("odd", background="#f2f5f9")


def _where():
    text = search_var.get().strip()
    if not text:
        return "", []
    if field.get() == "All columns":
        expr = "CONCAT_WS(' ', " + ", ".join(f"`{c}`" for c in state["cols"]) + ")"
    else:
        expr = f"`{field.get()}`"
    return f" WHERE {expr} LIKE %s", [f"%{text}%"]


def _update_status():
    shown = len(tree.get_children())
    status.config(text=f"Showing {shown:,} of {state['total']:,} rows"
                       + ("" if state["done"] else "  (scroll down for more)"))


def load_more():
    if state["loading"] or state["done"]:
        return
    state["loading"] = True
    try:
        where, params = _where()
        order = (f" ORDER BY `{state['sort']}` {'DESC' if state['desc'] else 'ASC'}"
                 if state["sort"] else " ORDER BY 1")
        _, rows = query(f"SELECT * FROM ({VIEWS[choice.get()]}) AS v{where}{order} "
                        f"LIMIT %s OFFSET %s", params + [PAGE, state["offset"]])
    except mysql.connector.Error as e:
        messagebox.showerror("Error", e.msg)
        return
    finally:
        state["loading"] = False
    for r in rows:
        tree.insert("", "end", values=r,
                    tags=("odd",) if len(tree.get_children()) % 2 else ())
    state["offset"] += len(rows)
    state["done"] = len(rows) < PAGE
    _update_status()


def reload(new_view=False):
    try:
        if new_view:
            cols, _ = query(f"SELECT * FROM ({VIEWS[choice.get()]}) AS v LIMIT 0")
            state.update(cols=cols, sort=None, desc=False)
            field["values"] = ["All columns"] + cols
            field.current(0)
            search_var.set("")
        where, params = _where()
        state["total"] = query(f"SELECT COUNT(*) FROM ({VIEWS[choice.get()]}) AS v{where}",
                               params)[1][0][0]
    except mysql.connector.Error as e:
        messagebox.showerror("Error", e.msg)
        return
    tree.delete(*tree.get_children())
    tree["columns"] = state["cols"]
    for c in state["cols"]:
        arrow = ""
        if state["sort"] == c:
            arrow = " ▼" if state["desc"] else " ▲"
        tree.heading(c, text=c + arrow, command=lambda c=c: sort_by(c))
        tree.column(c, width=120, stretch=False)
    state.update(offset=0, done=False)
    load_more()


def refresh(*_):
    reload(new_view=not state["cols"])


def sort_by(col):
    state["desc"] = state["sort"] == col and not state["desc"]
    state["sort"] = col
    reload()


def check_bottom(*_):
    if tree.yview()[1] >= 0.98:
        load_more()


_after = {"id": None}
def on_type(_e):                       # debounce: search 300 ms after typing stops
    if _after["id"]:
        root.after_cancel(_after["id"])
    _after["id"] = root.after(300, reload)


def clear_search():
    search_var.set("")
    reload()


ttk.Button(top, text="Clear", command=clear_search).pack(side="left")
ttk.Button(top, text="Refresh", command=refresh).pack(side="left", padx=8)

search_entry.bind("<KeyRelease>", on_type)
field.bind("<<ComboboxSelected>>", lambda e: reload())
choice.bind("<<ComboboxSelected>>", lambda e: reload(new_view=True))
tree.configure(yscrollcommand=lambda a, b: (vbar.set(a, b), check_bottom()),
               xscrollcommand=hbar.set)
for ev in ("<MouseWheel>", "<Button-4>", "<Button-5>", "<KeyRelease-Down>"):
    tree.bind(ev, lambda e: tree.after(50, check_bottom), add="+")

vbar.pack(side="right", fill="y")
hbar.pack(side="bottom", fill="x")
tree.pack(fill="both", expand=True)

tabs.add(make_form(tabs, ["OA ID", "Student ID", "Score"], "Save OA result",
         lambda v: run("sp_record_oa_result", (int(v[0]), int(v[1]), float(v[2]), 0),
                       lambda r: "OA result saved. Student PASSED, can now apply."
                                 if r[3] else "OA result saved. Student did NOT pass.")),
         text="Record OA Result")

tabs.add(make_form(tabs, ["Student ID", "Job ID"], "Apply",
         lambda v: run("sp_apply_for_job", (int(v[0]), int(v[1]), 0),
                       lambda r: f"Application created. ID = {r[2]}")),
         text="Apply")

tabs.add(make_form(tabs, ["Application ID", "Round ID", "Score", "Status (Pass/Fail/Absent)", "Remarks"],
                   "Save result",
         lambda v: run("sp_record_result",
                       (int(v[0]), int(v[1]), float(v[2]), v[3], v[4] or None, 0),
                       lambda r: f"Result saved. ID = {r[5]}")),
         text="Record Result")

tabs.add(make_form(tabs, ["Application ID", "CTC", "Joining date (YYYY-MM-DD)"], "Issue offer",
         lambda v: run("sp_issue_offer", (int(v[0]), float(v[1]), v[2], 0),
                       lambda r: f"Offer issued. ID = {r[3]}")),
         text="Issue Offer")

tabs.add(make_form(tabs, ["Offer ID"], "Accept offer",
         lambda v: run("sp_accept_offer", (int(v[0]),),
                       lambda r: "Offer accepted. Student's other pending offers were rejected.")),
         text="Accept Offer")

tabs.add(make_form(tabs, ["Application ID"], "Withdraw",
         lambda v: run("sp_withdraw_application", (int(v[0]),),
                       lambda r: "Application withdrawn. Pending offers revoked.")),
         text="Withdraw")

refresh()
root.mainloop()
