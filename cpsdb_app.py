import tkinter as tk
from tkinter import ttk, messagebox
import mysql.connector
import datetime



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
    "Student skills": """SELECT ss.Student_ID, s.Name AS Student, k.Skill_Name
                         FROM STUDENT_SKILL ss
                         JOIN STUDENT s ON s.Student_ID = ss.Student_ID
                         JOIN SKILL k ON k.Skill_ID = ss.Skill_ID""",
    "Job skills": """SELECT js.Job_ID, j.Job_Title, k.Skill_Name,
                            IF(js.Is_Compulsory, 'Compulsory', 'Optional') AS Type
                     FROM JOB_SKILL js
                     JOIN JOB_POSTING j ON j.Job_ID = js.Job_ID
                     JOIN SKILL k ON k.Skill_ID = js.Skill_ID""",
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
    """Call a stored procedure and show success or the error message.
    Returns True on success so forms know when to clear themselves."""
    try:
        result = call_proc(name, args)
        messagebox.showinfo("Done", ok_message(result))
        refresh()
        return True
    except mysql.connector.Error as e:
        messagebox.showerror("Error", e.msg)
    except ValueError as e:
        messagebox.showerror("Error", str(e) or "Please check the values entered.")
    return False



root = tk.Tk()
root.title("Campus Placement System")
root.geometry("900x500")
tabs = ttk.Notebook(root)
tabs.pack(fill="both", expand=True, padx=5, pady=5)


# Dropdown sources: each query returns (id, label); the id is what gets used.
LOOKUPS = {
    "department": "SELECT Dept_ID, Dept_Name FROM DEPARTMENT ORDER BY Dept_ID",
    "student": "SELECT Student_ID, Name FROM STUDENT ORDER BY Student_ID",
    "skill": "SELECT Skill_ID, Skill_Name FROM SKILL ORDER BY Skill_ID",
    "company": "SELECT Company_ID, Company_Name FROM COMPANY ORDER BY Company_ID",
    "oa": "SELECT OA_ID, OA_Name FROM ONLINE_ASSESSMENT ORDER BY OA_ID",
    "job": """SELECT j.Job_ID, CONCAT(j.Job_Title, ' @ ', c.Company_Name)
              FROM JOB_POSTING j JOIN COMPANY c ON c.Company_ID = j.Company_ID
              ORDER BY j.Job_ID""",
    "application": """SELECT a.Application_ID, CONCAT(s.Name, ' > ', j.Job_Title, ' [', a.Current_Status, ']')
                      FROM APPLICATION a
                      JOIN STUDENT s ON s.Student_ID = a.Student_ID
                      JOIN JOB_POSTING j ON j.Job_ID = a.Job_ID
                      ORDER BY a.Application_ID""",
    "round": """SELECT r.Round_ID, CONCAT(r.Round_Name, ' (', j.Job_Title, ')')
                FROM RECRUITMENT_ROUND r JOIN JOB_POSTING j ON j.Job_ID = r.Job_ID
                ORDER BY r.Round_ID""",
    "offer": """SELECT o.Offer_ID, CONCAT(s.Name, ' / ', c.Company_Name, ' [', o.Offer_Status, ']')
                FROM PLACEMENT_OFFER o
                JOIN APPLICATION a ON a.Application_ID = o.Application_ID
                JOIN STUDENT s ON s.Student_ID = a.Student_ID
                JOIN JOB_POSTING j ON j.Job_ID = a.Job_ID
                JOIN COMPANY c ON c.Company_ID = j.Company_ID
                ORDER BY o.Offer_ID""",
}


def lookup_values(key):
    try:
        _, rows = query(LOOKUPS[key] + " LIMIT 500")
    except mysql.connector.Error:
        return []
    return [f"{r[0]} - {r[1]}" for r in rows]


def convert(label, kind, text, required):
    """Turn the text typed/picked in a field into the value sent to MySQL."""
    text = text.strip()
    if not text:
        if required:
            raise ValueError(f"{label} is required.")
        return None
    if isinstance(kind, (list, tuple)):
        return text
    if kind == "bool":
        return 1 if text == "Yes" else 0
    try:
        if kind == "int" or kind in LOOKUPS:
            return int(text.split(" - ")[0])
        if kind == "num":
            return float(text)
        if kind == "date":
            datetime.date.fromisoformat(text)
    except ValueError:
        raise ValueError(f"{label}: '{text}' is not valid"
                         + (" (use YYYY-MM-DD)." if kind == "date" else "."))
    return text


def make_widget(parent, kind):
    if isinstance(kind, (list, tuple)):
        return ttk.Combobox(parent, values=list(kind), state="readonly", width=32)
    if kind == "bool":
        return ttk.Combobox(parent, values=["Yes", "No"], state="readonly", width=32)
    if kind in LOOKUPS:   # refreshed from the database every time it is opened
        box = ttk.Combobox(parent, width=32)
        box.configure(postcommand=lambda: box.configure(values=lookup_values(kind)))
        return box
    return ttk.Entry(parent, width=34)


def make_form(parent, fields, button_text, action):
    """fields: (label, kind[, required]) where kind is text, int, num, date, bool,
    a tuple of choices, or a LOOKUPS key (dropdown). action(values) gets converted
    values and returns True on success, which clears the form."""
    specs = [(f[0], f[1], f[2] if len(f) > 2 else True) for f in fields]
    frame = ttk.Frame(parent, padding=15)
    widgets = []
    for i, (label, kind, required) in enumerate(specs):
        ttk.Label(frame, text=label + (" *" if required else "")).grid(row=i, column=0, sticky="w", pady=3)
        w = make_widget(frame, kind)
        w.grid(row=i, column=1, pady=3, padx=10)
        widgets.append(w)

    def submit():
        try:
            values = [convert(l, k, w.get(), r) for (l, k, r), w in zip(specs, widgets)]
        except ValueError as e:
            messagebox.showerror("Error", str(e))
            return
        if action(values):
            for w in widgets:
                if isinstance(w, ttk.Combobox):
                    w.set("")
                else:
                    w.delete(0, "end")

    ttk.Button(frame, text=button_text, command=submit
               ).grid(row=len(specs), column=0, columnspan=2, pady=10)
    ttk.Label(frame, text="* required", foreground="#777").grid(row=len(specs) + 1, column=0, columnspan=2)
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

GENDERS = ("Male", "Female", "Other")
ROUND_TYPES = ("Aptitude", "Coding", "Technical", "GD", "HR")

# name -> (stored procedure, fields, procedure returns a new ID)
ENTITIES = {
    "Department": ("sp_add_department", [("Department name", "text"),
                   ("Head of department", "text", False), ("Contact", "text", False)], True),
    "Student": ("sp_add_student", [("Department", "department"), ("Roll no", "text"), ("Name", "text"),
                ("Gender", GENDERS, False), ("Email", "text", False), ("Phone", "text", False),
                ("CGPA", "num"), ("Backlogs (blank = 0)", "int", False), ("Passing year", "int")], True),
    "Skill": ("sp_add_skill", [("Skill name", "text")], True),
    "Student skill": ("sp_add_student_skill", [("Student", "student"), ("Skill", "skill")], False),
    "Company": ("sp_add_company", [("Company name", "text"), ("Industry", "text"),
                ("Address", "text", False), ("Website", "text", False),
                ("Contact", "text"), ("Email", "text")], True),
    "Online assessment": ("sp_add_oa", [("Company", "company"), ("Assessment name", "text"),
                          ("Passing score", "num")], True),
    "Job posting": ("sp_add_job", [("Company", "company"), ("Job title", "text"),
                    ("Description", "text", False), ("Min CGPA", "num"), ("Allowed backlogs", "int"),
                    ("CTC", "num"), ("Location", "text", False),
                    ("Application deadline (YYYY-MM-DD)", "date")], True),
    "Job skill": ("sp_add_job_skill", [("Job posting", "job"), ("Skill", "skill"),
                  ("Compulsory", "bool")], False),
    "Recruitment round": ("sp_add_round", [("Job posting", "job"), ("Round name", "text"),
                          ("Round type", ROUND_TYPES, False), ("Order (blank = next)", "int", False),
                          ("Description", "text", False)], True),
}

manage = ttk.Frame(tabs, padding=15)
tabs.add(manage, text="Manage Data")
ttk.Label(manage, text="Add new").grid(row=0, column=0, sticky="w")
pick = ttk.Combobox(manage, values=list(ENTITIES), state="readonly", width=32)
pick.current(0)
pick.grid(row=0, column=1, padx=10)
holder = ttk.Frame(manage)
holder.grid(row=1, column=0, columnspan=2, sticky="w")


def show_form(*_):
    for w in holder.winfo_children():
        w.destroy()
    name = pick.get()
    proc, fields, has_id = ENTITIES[name]
    ok = (lambda r: f"{name} added. ID = {r[-1]}") if has_id else (lambda r: f"{name} saved.")
    make_form(holder, fields, f"Save {name.lower()}",
              lambda v: run(proc, tuple(v) + ((0,) if has_id else ()), ok)).pack(anchor="w")


pick.bind("<<ComboboxSelected>>", show_form)
show_form()

tabs.add(make_form(tabs, [("Online assessment", "oa"), ("Student", "student"), ("Score", "num")],
                   "Save OA result",
         lambda v: run("sp_record_oa_result", (v[0], v[1], v[2], 0),
                       lambda r: "OA result saved. Student PASSED, can now apply."
                                 if r[3] else "OA result saved. Student did NOT pass.")),
         text="Record OA Result")

tabs.add(make_form(tabs, [("Student", "student"), ("Job posting", "job")], "Apply",
         lambda v: run("sp_apply_for_job", (v[0], v[1], 0),
                       lambda r: f"Application created. ID = {r[2]}")),
         text="Apply")

tabs.add(make_form(tabs, [("Application", "application"), ("Round", "round"),
                          ("Score", "num", False), ("Result", ("Pass", "Fail", "Absent")),
                          ("Remarks", "text", False)],
                   "Save result",
         lambda v: run("sp_record_result", (v[0], v[1], v[2], v[3], v[4], 0),
                       lambda r: f"Result saved. ID = {r[5]}")),
         text="Record Result")

tabs.add(make_form(tabs, [("Application", "application"), ("CTC (blank = job CTC)", "num", False),
                          ("Joining date (YYYY-MM-DD)", "date", False)], "Issue offer",
         lambda v: run("sp_issue_offer", (v[0], v[1], v[2], 0),
                       lambda r: f"Offer issued. ID = {r[3]}")),
         text="Issue Offer")

tabs.add(make_form(tabs, [("Offer", "offer")], "Accept offer",
         lambda v: run("sp_accept_offer", (v[0],),
                       lambda r: "Offer accepted. Student's other pending offers were rejected.")),
         text="Accept Offer")

tabs.add(make_form(tabs, [("Application", "application")], "Withdraw",
         lambda v: run("sp_withdraw_application", (v[0],),
                       lambda r: "Application withdrawn. Pending offers revoked.")),
         text="Withdraw")

refresh()
root.mainloop()
