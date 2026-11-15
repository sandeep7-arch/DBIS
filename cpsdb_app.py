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



def query(sql):
    conn = mysql.connector.connect(**DB)
    cur = conn.cursor()
    cur.execute(sql)
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


browse = ttk.Frame(tabs, padding=5)
tabs.add(browse, text="Browse")
top = ttk.Frame(browse)
top.pack(fill="x")
choice = ttk.Combobox(top, values=list(VIEWS), state="readonly", width=25)
choice.current(7)
choice.pack(side="left")
tree = ttk.Treeview(browse, show="headings")
scroll = ttk.Scrollbar(browse, command=tree.yview)
tree.configure(yscrollcommand=scroll.set)


def refresh(*_):
    try:
        cols, rows = query(VIEWS[choice.get()])
    except mysql.connector.Error as e:
        messagebox.showerror("Error", e.msg)
        return
    tree.delete(*tree.get_children())
    tree["columns"] = cols
    for c in cols:
        tree.heading(c, text=c)
        tree.column(c, width=110)
    for r in rows:
        tree.insert("", "end", values=r)


ttk.Button(top, text="Refresh", command=refresh).pack(side="left", padx=8)
choice.bind("<<ComboboxSelected>>", refresh)
scroll.pack(side="right", fill="y")
tree.pack(fill="both", expand=True, pady=5)

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
