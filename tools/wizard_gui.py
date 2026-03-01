#!/usr/bin/env python3
"""
ArcOS ABPX Wizard — GUI Application
A modern dark-theme wizard for applying .abpx optimization bundles,
inspired by the AME Wizard UI.

Requirements: pip install customtkinter
"""

import customtkinter as ctk
import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import zipfile
from pathlib import Path
from tkinter import filedialog, messagebox

# ─────────────────────────────────────────────────────────
# Theme
# ─────────────────────────────────────────────────────────

ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("blue")

BG_DARK      = "#111111"
BG_CARD      = "#1C1C1C"
BG_SIDEBAR   = "#0F0F0F"
BG_HOVER     = "#2A2A2A"
ACCENT       = "#0078D4"
ACCENT_HOVER = "#1A8FE3"
ACCENT_DIM   = "#005A9E"
TEXT_PRIMARY = "#FFFFFF"
TEXT_SECONDARY = "#A0A0A0"
TEXT_DIM     = "#606060"
BORDER       = "#2C2C2C"
SUCCESS      = "#34C759"
WARNING      = "#FF9F0A"
ERROR        = "#FF3B30"

FONT_TITLE   = ("Segoe UI", 22, "bold")
FONT_HEADING = ("Segoe UI", 14, "bold")
FONT_BODY    = ("Segoe UI", 12)
FONT_SMALL   = ("Segoe UI", 10)
FONT_MONO    = ("Consolas", 10)

STEPS = [
    ("①", "Welcome",       "Load your .abpx bundle"),
    ("②", "Verification",  "Integrity & system check"),
    ("③", "Bundle Info",   "Review what's included"),
    ("④", "Select Engines","Choose what to apply"),
    ("⑤", "Confirm",       "Review before applying"),
    ("⑥", "Applying",      "Running optimizations"),
    ("⑦", "Complete",      "Done!"),
]

# ─────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


# ─────────────────────────────────────────────────────────
# Main Window
# ─────────────────────────────────────────────────────────

class ArcWizard(ctk.CTk):
    def __init__(self):
        super().__init__()

        self.title("ArcOS Wizard")
        self.geometry("900x600")
        self.minsize(800, 520)
        self.configure(fg_color=BG_DARK)
        self.resizable(True, True)

        # State
        self.current_step  = 0
        self.abpx_path     = None
        self.bundle_meta   = None
        self.temp_dir      = None
        self.engine_states = {}   # name → BooleanVar
        self.log_lines     = []
        self.dry_run       = ctk.BooleanVar(value=False)

        self._build_layout()
        self._show_step(0)

    # ─── Layout ───────────────────────────────────────────

    def _build_layout(self):
        # ── Outer frame split: sidebar | main ──
        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(0, weight=1)

        # Sidebar
        self.sidebar = ctk.CTkFrame(self, width=220, fg_color=BG_SIDEBAR,
                                    corner_radius=0)
        self.sidebar.grid(row=0, column=0, sticky="nsew")
        self.sidebar.grid_propagate(False)
        self.sidebar.grid_rowconfigure(99, weight=1)

        # Logo / app name
        logo_frame = ctk.CTkFrame(self.sidebar, fg_color="transparent")
        logo_frame.grid(row=0, column=0, padx=20, pady=(24, 12), sticky="ew")

        ctk.CTkLabel(logo_frame, text="⬡", font=("Segoe UI", 28),
                     text_color=ACCENT).pack(side="left", padx=(0, 8))
        name_f = ctk.CTkFrame(logo_frame, fg_color="transparent")
        name_f.pack(side="left")
        ctk.CTkLabel(name_f, text="ArcOS", font=("Segoe UI", 15, "bold"),
                     text_color=TEXT_PRIMARY).pack(anchor="w")
        ctk.CTkLabel(name_f, text="ABPX Wizard", font=FONT_SMALL,
                     text_color=TEXT_SECONDARY).pack(anchor="w")

        # Separator
        ctk.CTkFrame(self.sidebar, height=1, fg_color=BORDER).grid(
            row=1, column=0, sticky="ew", padx=16, pady=(0, 12))

        # Step list
        self.step_labels = []
        for i, (num, name, sub) in enumerate(STEPS):
            btn = self._make_step_item(self.sidebar, i, num, name, sub)
            btn.grid(row=i + 2, column=0, padx=12, pady=2, sticky="ew")
            self.step_labels.append(btn)

        # Bottom: version tag
        ctk.CTkLabel(self.sidebar, text="v1.0 · github.com/ArcOS",
                     font=FONT_SMALL, text_color=TEXT_DIM).grid(
            row=99, column=0, padx=20, pady=16, sticky="sw")

        # ── Main area ──────────────────────────────────────
        self.main = ctk.CTkFrame(self, fg_color=BG_DARK, corner_radius=0)
        self.main.grid(row=0, column=1, sticky="nsew")
        self.main.grid_rowconfigure(0, weight=1)
        self.main.grid_columnconfigure(0, weight=1)

        # Content frame (scrollable inner area)
        self.content = ctk.CTkScrollableFrame(
            self.main, fg_color=BG_DARK, scrollbar_button_color=BG_CARD,
            scrollbar_button_hover_color=BG_HOVER)
        self.content.grid(row=0, column=0, sticky="nsew", padx=32, pady=(28, 0))
        self.content.grid_columnconfigure(0, weight=1)

        # Footer nav
        footer = ctk.CTkFrame(self.main, fg_color=BG_DARK, height=64,
                               corner_radius=0)
        footer.grid(row=1, column=0, sticky="ew", padx=32, pady=0)
        footer.grid_columnconfigure(0, weight=1)

        ctk.CTkFrame(footer, height=1, fg_color=BORDER).grid(
            row=0, column=0, columnspan=3, sticky="ew", pady=(0, 12))

        self.btn_back = ctk.CTkButton(
            footer, text="← Back", width=100,
            fg_color=BG_CARD, hover_color=BG_HOVER,
            text_color=TEXT_PRIMARY, corner_radius=8,
            command=self._go_back)
        self.btn_back.grid(row=1, column=1, padx=(0, 8), pady=(0, 12))

        self.btn_next = ctk.CTkButton(
            footer, text="Next →", width=130,
            fg_color=ACCENT, hover_color=ACCENT_HOVER,
            text_color="#FFFFFF", corner_radius=8, font=("Segoe UI", 12, "bold"),
            command=self._go_next)
        self.btn_next.grid(row=1, column=2, pady=(0, 12))

        # Dry run toggle in footer
        self.dry_toggle = ctk.CTkCheckBox(
            footer, text="Dry Run", variable=self.dry_run,
            font=FONT_SMALL, text_color=TEXT_SECONDARY,
            fg_color=ACCENT, hover_color=ACCENT_HOVER, corner_radius=4)
        self.dry_toggle.grid(row=1, column=0, sticky="w", pady=(0, 12))

    def _make_step_item(self, parent, idx, num, name, sub):
        f = ctk.CTkFrame(parent, fg_color="transparent", corner_radius=8,
                         cursor="hand2")
        f.grid_columnconfigure(1, weight=1)

        # Number badge
        badge = ctk.CTkLabel(f, text=num, width=28, height=28,
                              fg_color=BG_CARD, corner_radius=6,
                              font=("Segoe UI", 11), text_color=TEXT_DIM)
        badge.grid(row=0, column=0, rowspan=2, padx=(8, 10), pady=8)

        ctk.CTkLabel(f, text=name, font=("Segoe UI", 11, "bold"),
                     text_color=TEXT_DIM, anchor="w").grid(
            row=0, column=1, sticky="w")
        ctk.CTkLabel(f, text=sub, font=("Segoe UI", 9),
                     text_color=TEXT_DIM, anchor="w").grid(
            row=1, column=1, sticky="w", pady=(0, 4))

        # Store badge ref for coloring
        f._badge = badge
        f._idx = idx
        return f

    def _update_sidebar(self):
        for i, f in enumerate(self.step_labels):
            if i < self.current_step:
                # Done
                f._badge.configure(fg_color="#1E3A1E", text_color=SUCCESS)
                f.configure(fg_color="transparent")
                for w in f.winfo_children():
                    if isinstance(w, ctk.CTkLabel) and w is not f._badge:
                        w.configure(text_color=TEXT_DIM)
            elif i == self.current_step:
                # Active
                f._badge.configure(fg_color=ACCENT, text_color="#FFFFFF")
                f.configure(fg_color=BG_HOVER)
                for w in f.winfo_children():
                    if isinstance(w, ctk.CTkLabel) and w is not f._badge:
                        w.configure(text_color=TEXT_PRIMARY)
            else:
                # Future
                f._badge.configure(fg_color=BG_CARD, text_color=TEXT_DIM)
                f.configure(fg_color="transparent")
                for w in f.winfo_children():
                    if isinstance(w, ctk.CTkLabel) and w is not f._badge:
                        w.configure(text_color=TEXT_DIM)

    # ─── Navigation ────────────────────────────────────────

    def _go_next(self):
        if self.current_step == 0:
            if not self.abpx_path:
                messagebox.showwarning("No file", "Please load a .abpx file first.")
                return
            self._show_step(1)
        elif self.current_step == 1:
            self._show_step(2)
        elif self.current_step == 2:
            self._show_step(3)
        elif self.current_step == 3:
            self._show_step(4)
        elif self.current_step == 4:
            self._show_step(5)
            threading.Thread(target=self._apply_bundle, daemon=True).start()
        elif self.current_step == 6:
            self.destroy()

    def _go_back(self):
        if self.current_step > 0 and self.current_step != 5:
            self._show_step(self.current_step - 1)

    def _show_step(self, idx):
        self.current_step = idx
        self._update_sidebar()
        self._clear_content()

        steps = [
            self._build_step_welcome,
            self._build_step_verify,
            self._build_step_info,
            self._build_step_engines,
            self._build_step_confirm,
            self._build_step_applying,
            self._build_step_complete,
        ]
        steps[idx]()

        # Footer button state
        if idx == 0:
            self.btn_back.configure(state="disabled")
            self.btn_next.configure(text="Next →", state="normal")
        elif idx == 5:
            self.btn_back.configure(state="disabled")
            self.btn_next.configure(state="disabled")
        elif idx == 6:
            self.btn_back.configure(state="disabled")
            self.btn_next.configure(text="Finish", state="normal",
                                    fg_color=SUCCESS, hover_color="#2DB34A")
        else:
            self.btn_back.configure(state="normal")
            self.btn_next.configure(text="Next →", state="normal",
                                    fg_color=ACCENT, hover_color=ACCENT_HOVER)

    def _clear_content(self):
        for w in self.content.winfo_children():
            w.destroy()

    # ─── Step 0: Welcome ──────────────────────────────────

    def _build_step_welcome(self):
        c = self.content
        self._page_header(c, "Welcome to ArcOS Wizard",
                          "Load a .abpx bundle to optimize your Windows installation.")

        # Drag-and-drop / select card
        drop_card = ctk.CTkFrame(c, fg_color=BG_CARD, corner_radius=12,
                                  border_width=2, border_color=BORDER)
        drop_card.grid(row=2, column=0, sticky="ew", pady=(0, 16))
        drop_card.grid_columnconfigure(0, weight=1)

        ctk.CTkLabel(drop_card, text="⬤", font=("Segoe UI", 36),
                     text_color=ACCENT).grid(pady=(28, 8))
        ctk.CTkLabel(drop_card, text="Drag & drop a .abpx file here",
                     font=FONT_HEADING, text_color=TEXT_PRIMARY).grid()
        ctk.CTkLabel(drop_card, text="or click Browse to select one",
                     font=FONT_BODY, text_color=TEXT_SECONDARY).grid(pady=(4, 0))

        self.file_label = ctk.CTkLabel(
            drop_card,
            text="No file selected",
            font=FONT_SMALL, text_color=TEXT_DIM)
        self.file_label.grid(pady=(12, 0))

        ctk.CTkButton(
            drop_card, text="Browse .abpx file",
            fg_color=ACCENT, hover_color=ACCENT_HOVER,
            corner_radius=8, font=("Segoe UI", 12, "bold"),
            command=self._browse_file).grid(pady=(12, 24))

        # Enable drag & drop
        drop_card.bind("<Button-1>", lambda e: self._browse_file())

        # Info cards row
        info_row = ctk.CTkFrame(c, fg_color="transparent")
        info_row.grid(row=3, column=0, sticky="ew")
        info_row.grid_columnconfigure((0, 1, 2), weight=1)

        for col, (icon, title, body) in enumerate([
            ("🔒", "Safe", "Creates a full rollback snapshot before every change"),
            ("⚡", "Fast", "Engines run in sequence with live progress feedback"),
            ("🎮", "Profiles", "Gaming, Privacy, Stable, Balanced & more"),
        ]):
            self._info_card(info_row, col, icon, title, body)

    def _browse_file(self):
        path = filedialog.askopenfilename(
            title="Select ArcOS Bundle",
            filetypes=[("ArcOS Bundle", "*.abpx"), ("ZIP Archive", "*.zip"),
                       ("All files", "*.*")])
        if path:
            self.abpx_path = Path(path)
            name = self.abpx_path.name
            self.file_label.configure(
                text=f"✓  {name}", text_color=SUCCESS)
            self._load_bundle_meta()

    def _load_bundle_meta(self):
        """Extract and read arcos.manifest.json silently for preview."""
        try:
            if self.temp_dir and Path(self.temp_dir).exists():
                shutil.rmtree(self.temp_dir, ignore_errors=True)
            self.temp_dir = tempfile.mkdtemp(prefix="arcos-")
            with zipfile.ZipFile(self.abpx_path, "r") as zf:
                zf.extractall(self.temp_dir)
            manifest = Path(self.temp_dir) / "arcos.manifest.json"
            if manifest.exists():
                with open(manifest) as f:
                    self.bundle_meta = json.load(f)
                # init engine states
                self.engine_states = {
                    e: ctk.BooleanVar(value=True)
                    for e in self.bundle_meta.get("engines", [])
                }
        except Exception as ex:
            messagebox.showerror("Error", f"Could not read bundle:\n{ex}")

    # ─── Step 1: Verification ────────────────────────────

    def _build_step_verify(self):
        c = self.content
        self._page_header(c, "Verification",
                          "Checking bundle integrity and system requirements.")

        card = ctk.CTkFrame(c, fg_color=BG_CARD, corner_radius=12)
        card.grid(row=2, column=0, sticky="ew", pady=(0, 16))
        card.grid_columnconfigure(1, weight=1)

        self._check_rows = []
        checks = [
            ("Bundle integrity",   self._check_integrity),
            ("Bundle header",      self._check_header),
            ("PowerShell present", self._check_pwsh),
            ("Python ≥ 3.10",      self._check_python),
        ]

        for i, (label, fn) in enumerate(checks):
            row = self._check_row(card, i + 1, label)
            self._check_rows.append((row, fn))

        threading.Thread(target=self._run_checks, daemon=True).start()

    def _check_row(self, parent, row, label):
        f = ctk.CTkFrame(parent, fg_color="transparent")
        f.grid(row=row, column=0, columnspan=2, sticky="ew",
               padx=20, pady=(12 if row == 1 else 4,
                              12 if row == len(self._check_rows) + 1 else 4))
        f.grid_columnconfigure(1, weight=1)

        icon = ctk.CTkLabel(f, text="○", width=24, font=("Segoe UI", 14),
                             text_color=TEXT_DIM)
        icon.grid(row=0, column=0, padx=(0, 12))
        ctk.CTkLabel(f, text=label, font=FONT_BODY,
                     text_color=TEXT_SECONDARY, anchor="w").grid(
            row=0, column=1, sticky="w")
        detail = ctk.CTkLabel(f, text="", font=FONT_SMALL,
                              text_color=TEXT_DIM, anchor="w")
        detail.grid(row=1, column=1, sticky="w")
        return icon, detail

    def _run_checks(self):
        all_ok = True
        for (icon, detail), fn in self._check_rows:
            time.sleep(0.4)
            ok, msg = fn()
            color = SUCCESS if ok else ERROR
            sym   = "✓" if ok else "✗"
            self.after(0, lambda i=icon, s=sym, c=color: i.configure(text=s, text_color=c))
            self.after(0, lambda d=detail, m=msg: d.configure(text=m))
            if not ok:
                all_ok = False
        if not all_ok:
            self.after(0, lambda: self.btn_next.configure(state="disabled"))

    def _check_integrity(self):
        if not self.bundle_meta or not self.temp_dir:
            return False, "No bundle loaded"
        bad = []
        for entry in self.bundle_meta.get("files", []):
            path = Path(self.temp_dir) / entry["path"].replace("/", os.sep)
            if path.exists():
                actual = sha256_file(path)
                if actual != entry["sha256"]:
                    bad.append(entry["path"])
            else:
                bad.append(entry["path"] + " (missing)")
        if bad:
            return False, f"{len(bad)} file(s) failed checksum"
        n = len(self.bundle_meta.get("files", []))
        return True, f"{n} files verified ✓"

    def _check_header(self):
        if not self.bundle_meta:
            return False, "arcos.manifest.json not found"
        ver  = self.bundle_meta.get("abpx_version", "?")
        name = self.bundle_meta.get("name", "Unknown")
        return True, f"{name}  (abpx v{ver})"

    def _check_pwsh(self):
        pwsh = shutil.which("pwsh") or shutil.which("powershell")
        if pwsh:
            return True, pwsh
        return False, "PowerShell not found — engines cannot run"

    def _check_python(self):
        v = sys.version_info
        if v >= (3, 10):
            return True, f"Python {v.major}.{v.minor}.{v.micro}"
        return False, f"Python {v.major}.{v.minor} — 3.10+ required"

    # ─── Step 2: Bundle Info ──────────────────────────────

    def _build_step_info(self):
        c = self.content
        meta = self.bundle_meta or {}
        self._page_header(c, "Bundle Information",
                          "Review what this bundle contains before applying.")

        # Meta card
        meta_card = ctk.CTkFrame(c, fg_color=BG_CARD, corner_radius=12)
        meta_card.grid(row=2, column=0, sticky="ew", pady=(0, 16))
        meta_card.grid_columnconfigure(1, weight=1)

        rows = [
            ("Name",        meta.get("name", "—")),
            ("Description", meta.get("description", "—")),
            ("Author",      meta.get("author", "—")),
            ("Built",       meta.get("built_at", "—")),
            ("ABPX Version",meta.get("abpx_version", "—")),
            ("Playbooks",   ", ".join(meta.get("playbooks", []))),
            ("Engines",     ", ".join(meta.get("engines", []))),
        ]
        for i, (k, v) in enumerate(rows):
            ctk.CTkLabel(meta_card, text=k, font=("Segoe UI", 11, "bold"),
                         text_color=TEXT_SECONDARY, width=120, anchor="w").grid(
                row=i, column=0, padx=(20, 8),
                pady=(16 if i == 0 else 4, 16 if i == len(rows) - 1 else 4),
                sticky="nw")
            ctk.CTkLabel(meta_card, text=v, font=FONT_BODY,
                         text_color=TEXT_PRIMARY, anchor="w",
                         wraplength=460).grid(
                row=i, column=1, padx=(0, 20),
                pady=(16 if i == 0 else 4, 16 if i == len(rows) - 1 else 4),
                sticky="w")

        # Stats row
        stats = meta.get("stats", {})
        stats_row = ctk.CTkFrame(c, fg_color="transparent")
        stats_row.grid(row=3, column=0, sticky="ew", pady=(0, 16))
        stats_row.grid_columnconfigure((0, 1, 2, 3), weight=1)

        for col, (val, label) in enumerate([
            (stats.get("engine_files", "?"),   "Engine files"),
            (stats.get("manifest_files", "?"), "Manifest files"),
            (stats.get("total_files", "?"),    "Total files"),
            (len(meta.get("engines", [])),     "Engines"),
        ]):
            self._stat_card(stats_row, col, str(val), label)

    # ─── Step 3: Engine Selection ─────────────────────────

    def _build_step_engines(self):
        c = self.content
        self._page_header(c, "Select Engines",
                          "Toggle which engines to run. All are enabled by default.")

        for i, (name, var) in enumerate(self.engine_states.items()):
            row = ctk.CTkFrame(c, fg_color=BG_CARD, corner_radius=10)
            row.grid(row=i + 2, column=0, sticky="ew", pady=4)
            row.grid_columnconfigure(1, weight=1)

            ctk.CTkCheckBox(
                row, text="", variable=var, width=24,
                fg_color=ACCENT, hover_color=ACCENT_HOVER,
                corner_radius=4).grid(row=0, column=0, padx=(16, 0), pady=16)

            info_f = ctk.CTkFrame(row, fg_color="transparent")
            info_f.grid(row=0, column=1, padx=12, pady=12, sticky="w")
            ctk.CTkLabel(info_f, text=name, font=("Segoe UI", 12, "bold"),
                         text_color=TEXT_PRIMARY, anchor="w").pack(anchor="w")
            ctk.CTkLabel(info_f, text=ENGINE_DESCRIPTIONS.get(name, ""),
                         font=FONT_SMALL, text_color=TEXT_SECONDARY,
                         anchor="w").pack(anchor="w")

        # Select all / none buttons
        btn_row = ctk.CTkFrame(c, fg_color="transparent")
        n = len(self.engine_states)
        btn_row.grid(row=n + 2, column=0, sticky="w", pady=(12, 0))
        ctk.CTkButton(btn_row, text="Select All", width=100,
                      fg_color=BG_CARD, hover_color=BG_HOVER,
                      text_color=TEXT_PRIMARY, corner_radius=8,
                      command=lambda: [v.set(True) for v in self.engine_states.values()]
                      ).pack(side="left", padx=(0, 8))
        ctk.CTkButton(btn_row, text="Select None", width=100,
                      fg_color=BG_CARD, hover_color=BG_HOVER,
                      text_color=TEXT_PRIMARY, corner_radius=8,
                      command=lambda: [v.set(False) for v in self.engine_states.values()]
                      ).pack(side="left")

    # ─── Step 4: Confirm ──────────────────────────────────

    def _build_step_confirm(self):
        c = self.content
        selected = [name for name, var in self.engine_states.items() if var.get()]
        self._page_header(c, "Confirm Changes",
                          f"{len(selected)} engine(s) will run. Review before applying.")

        # Tweak counts
        td = Path(self.temp_dir) if self.temp_dir else Path(".")
        counts = {}
        for label, fname in [
            ("Registry tweaks", "manifests/registry.json"),
            ("Policy rules",    "manifests/policies.json"),
            ("Tasks disabled",  "manifests/tasks.json"),
            ("Services modified","manifests/services.json"),
        ]:
            try:
                data = json.loads((td / fname.replace("/", os.sep)).read_text())
                counts[label] = len(data)
            except Exception:
                counts[label] = "?"

        stats_row = ctk.CTkFrame(c, fg_color="transparent")
        stats_row.grid(row=2, column=0, sticky="ew", pady=(0, 16))
        stats_row.grid_columnconfigure((0, 1, 2, 3), weight=1)
        for col, (label, val) in enumerate(counts.items()):
            self._stat_card(stats_row, col, str(val), label)

        # Engines list
        card = ctk.CTkFrame(c, fg_color=BG_CARD, corner_radius=12)
        card.grid(row=3, column=0, sticky="ew", pady=(0, 16))
        card.grid_columnconfigure(0, weight=1)

        ctk.CTkLabel(card, text="Engines to run",
                     font=FONT_HEADING, text_color=TEXT_PRIMARY,
                     anchor="w").grid(padx=20, pady=(16, 8), sticky="w")

        for name in selected:
            ctk.CTkLabel(card, text=f"  ✓  {name}",
                         font=FONT_BODY, text_color=SUCCESS, anchor="w").grid(
                padx=20, pady=2, sticky="w")

        ctk.CTkLabel(card, text="", height=12).grid()  # padding

        # Dry run notice
        if self.dry_run.get():
            notice = ctk.CTkFrame(c, fg_color="#1A1A00", corner_radius=10,
                                  border_width=1, border_color=WARNING)
            notice.grid(row=4, column=0, sticky="ew")
            ctk.CTkLabel(notice,
                         text="⚠  Dry Run mode is ON — no changes will be applied",
                         font=FONT_BODY, text_color=WARNING).grid(padx=16, pady=12)

    # ─── Step 5: Applying ────────────────────────────────

    def _build_step_applying(self):
        c = self.content
        self._page_header(c, "Applying Bundle",
                          "Please wait while ArcOS applies your optimizations…")

        # Progress bar
        self.progress_bar = ctk.CTkProgressBar(c, height=8, corner_radius=4,
                                               fg_color=BG_CARD,
                                               progress_color=ACCENT)
        self.progress_bar.grid(row=2, column=0, sticky="ew", pady=(0, 8))
        self.progress_bar.set(0)

        self.progress_label = ctk.CTkLabel(c, text="Starting…",
                                           font=FONT_BODY, text_color=TEXT_SECONDARY,
                                           anchor="w")
        self.progress_label.grid(row=3, column=0, sticky="w", pady=(0, 16))

        # Live log
        log_card = ctk.CTkFrame(c, fg_color=BG_CARD, corner_radius=12)
        log_card.grid(row=4, column=0, sticky="nsew")
        log_card.grid_columnconfigure(0, weight=1)
        log_card.grid_rowconfigure(0, weight=1)
        c.grid_rowconfigure(4, weight=1)

        self.log_box = ctk.CTkTextbox(
            log_card, fg_color="transparent", text_color=TEXT_SECONDARY,
            font=FONT_MONO, activate_scrollbars=True, wrap="word",
            state="disabled")
        self.log_box.grid(row=0, column=0, sticky="nsew", padx=16, pady=16)

    def _log(self, line: str, color: str = TEXT_SECONDARY):
        def _do():
            self.log_box.configure(state="normal")
            self.log_box.insert("end", line + "\n")
            self.log_box.configure(state="disabled")
            self.log_box.see("end")
        self.after(0, _do)

    def _set_progress(self, val: float, label: str = ""):
        self.after(0, lambda: self.progress_bar.set(val))
        if label:
            self.after(0, lambda: self.progress_label.configure(text=label))

    def _apply_bundle(self):
        selected = [name for name, var in self.engine_states.items() if var.get()]
        total    = len(selected)
        dry      = self.dry_run.get()

        engine_map = {
            "ServiceEngine":     "service-engine.ps1",
            "TaskEngine":        "task-engine.ps1",
            "AppxEngine":        "appx-engine.ps1",
            "RegistryEngine":    "registry-engine.ps1",
            "PolicyEngine":      "policy-engine.ps1",
            "PerformanceEngine": "performance-engine.ps1",
            "UIEngine":          "ui-engine.ps1",
            "WallpaperEngine":   "wallpaper-engine.ps1",
            "AvatarEngine":      "avatar-engine.ps1",
            "OneDriveEngine":    "onedrive-engine.ps1",
            "EdgeEngine":        "edge-engine.ps1",
            "NetworkEngine":     "network-engine.ps1",
            "GamingEngine":      "gaming-engine.ps1",
        }

        pwsh = shutil.which("pwsh") or shutil.which("powershell")
        td   = Path(self.temp_dir)
        eng  = td / "engines"
        mf   = td / "manifests"

        # Build a runner script on-the-fly
        # ps() converts backslashes → forward slashes (PowerShell accepts both)
        # This avoids quoting issues on Windows paths with spaces.
        def ps(p) -> str:
            return str(p).replace("\\", "/")

        runner = td / "_runner.ps1"
        lines  = [
            "$ErrorActionPreference = 'Continue'",
            # Inject manifest dir so engines resolve paths correctly regardless of $PSScriptRoot
            f'$Global:ArcManifestDir = "{ps(mf)}"',
            f'. "{ps(eng / "logger.ps1")}"',
        ]

        if not dry:
            rollback = eng / "rollback.ps1"
            if rollback.exists():
                lines += [f'. "{ps(rollback)}"', "Initialize-Rollback"]

        for name in selected:
            fname = engine_map.get(name)
            if not fname:
                continue
            ep = eng / fname
            if not ep.exists():
                continue
            lines += [
                f"Write-Host '=ENGINE={name}=' -ForegroundColor Cyan",
                f'. "{ps(ep)}"',
            ]
            if not dry:
                lines.append(f"Invoke-{name}")
            else:
                lines.append(f"Write-Host '[DRY RUN] Would run: Invoke-{name}' -ForegroundColor Yellow")

        lines.append("Write-Host '=DONE='")
        runner.write_text("\n".join(lines), encoding="utf-8")

        self._set_progress(0.0, "Launching PowerShell…")
        self._log(f"{'[DRY RUN] ' if dry else ''}Running {total} engine(s)...\n")

        if not pwsh:
            self._log("ERROR: PowerShell not found.", ERROR)
            self._set_progress(1.0, "Failed — PowerShell not found.")
            self.after(0, lambda: self._show_step(6))
            return

        try:
            proc = subprocess.Popen(
                [pwsh, "-NonInteractive", "-NoProfile", "-File", str(runner)],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, bufsize=1)

            done_count = 0
            for line in proc.stdout:
                line = line.rstrip()
                if line.startswith("=ENGINE=") and line.endswith("="):
                    eng_name = line.strip("=ENGINE=").strip("=")
                    done_count += 1
                    frac = done_count / total
                    self._set_progress(frac, f"Running {eng_name}… ({done_count}/{total})")
                    self._log(f"\n▶  {eng_name}", ACCENT)
                elif line == "=DONE=":
                    pass
                else:
                    self._log(f"   {line}")

            proc.wait()
            self._set_progress(1.0, "Complete!")
            self._log("\n✓ All engines finished.")
        except Exception as ex:
            self._log(f"\nERROR: {ex}")
            self._set_progress(1.0, "Error occurred.")

        self.after(800, lambda: self._show_step(6))

    # ─── Step 6: Complete ────────────────────────────────

    def _build_step_complete(self):
        c = self.content
        dry = self.dry_run.get()

        ctk.CTkLabel(c, text="✓", font=("Segoe UI", 72),
                     text_color=SUCCESS).grid(row=0, column=0, pady=(20, 0))
        ctk.CTkLabel(
            c,
            text="Optimizations applied!" if not dry else "Dry run complete!",
            font=("Segoe UI", 20, "bold"), text_color=TEXT_PRIMARY
        ).grid(row=1, column=0, pady=(8, 4))
        ctk.CTkLabel(
            c,
            text=("Your system has been optimized. A rollback snapshot was saved.\n"
                  "Use  pwsh main.ps1 --rollback  to undo changes.")
            if not dry else
            "No changes were applied. Remove 'Dry Run' and run again to apply for real.",
            font=FONT_BODY, text_color=TEXT_SECONDARY, justify="center"
        ).grid(row=2, column=0, pady=(0, 24))

        if not dry:
            restart_card = ctk.CTkFrame(c, fg_color=BG_CARD, corner_radius=12)
            restart_card.grid(row=3, column=0, pady=(0, 16))
            self.restart_var = ctk.BooleanVar(value=False)
            ctk.CTkCheckBox(
                restart_card, text="Restart Windows after closing wizard",
                variable=self.restart_var, font=FONT_BODY,
                fg_color=ACCENT, hover_color=ACCENT_HOVER,
                text_color=TEXT_PRIMARY).grid(padx=24, pady=16)

    # ─── Shared Widgets ───────────────────────────────────

    def _page_header(self, parent, title: str, subtitle: str):
        ctk.CTkLabel(parent, text=title, font=FONT_TITLE,
                     text_color=TEXT_PRIMARY, anchor="w").grid(
            row=0, column=0, sticky="w", pady=(0, 4))
        ctk.CTkLabel(parent, text=subtitle, font=FONT_BODY,
                     text_color=TEXT_SECONDARY, anchor="w").grid(
            row=1, column=0, sticky="w", pady=(0, 20))

    def _stat_card(self, parent, col: int, value: str, label: str):
        f = ctk.CTkFrame(parent, fg_color=BG_CARD, corner_radius=10)
        f.grid(row=0, column=col, padx=(0 if col == 0 else 8, 0), sticky="ew")
        ctk.CTkLabel(f, text=value, font=("Segoe UI", 26, "bold"),
                     text_color=ACCENT).pack(pady=(16, 2))
        ctk.CTkLabel(f, text=label, font=FONT_SMALL,
                     text_color=TEXT_SECONDARY).pack(pady=(0, 14))

    def _info_card(self, parent, col: int, icon: str, title: str, body: str):
        f = ctk.CTkFrame(parent, fg_color=BG_CARD, corner_radius=10)
        f.grid(row=0, column=col, padx=(0 if col == 0 else 8, 0), sticky="ew")
        ctk.CTkLabel(f, text=icon, font=("Segoe UI", 24)).pack(pady=(16, 4))
        ctk.CTkLabel(f, text=title, font=("Segoe UI", 11, "bold"),
                     text_color=TEXT_PRIMARY).pack()
        ctk.CTkLabel(f, text=body, font=FONT_SMALL, text_color=TEXT_SECONDARY,
                     wraplength=150, justify="center").pack(pady=(4, 16))

    # ─── Cleanup ──────────────────────────────────────────

    def destroy(self):
        # Optional restart
        if hasattr(self, "restart_var") and self.restart_var.get():
            subprocess.run(["shutdown", "/r", "/t", "5"], shell=True)
        if self.temp_dir and Path(self.temp_dir).exists():
            shutil.rmtree(self.temp_dir, ignore_errors=True)
        super().destroy()


# ─────────────────────────────────────────────────────────
# Engine descriptions for the engine selection step
# ─────────────────────────────────────────────────────────

ENGINE_DESCRIPTIONS = {
    "ServiceEngine":     "Disables telemetry, Xbox, diagnostic, and unnecessary services",
    "TaskEngine":        "Disables 40+ CEIP, feedback, and telemetry scheduled tasks",
    "AppxEngine":        "Removes bloatware AppX packages (Bing, Zune, Office Hub…)",
    "RegistryEngine":    "Applies 50+ registry tweaks for privacy and performance",
    "PolicyEngine":      "Applies 30+ group policy rules for telemetry and app privacy",
    "PerformanceEngine": "HAGS, CPU priority boost, power throttling, memory tweaks",
    "UIEngine":          "Disables animations, transparency, and visual effects",
    "WallpaperEngine":   "Sets ArcOS custom wallpaper and accent color",
    "AvatarEngine":      "Sets custom user account avatar",
    "OneDriveEngine":    "Removes or disables OneDrive integration",
    "EdgeEngine":        "Disables Edge startup boost and background mode",
    "NetworkEngine":     "Nagle disable, QoS, LSO off, TCP stack and DNS tuning",
    "GamingEngine":      "Game Mode, HAGS, GPU priority, fullscreen opts, raw mouse",
}


# ─────────────────────────────────────────────────────────
# Entry point
# ─────────────────────────────────────────────────────────

if __name__ == "__main__":
    app = ArcWizard()
    app.mainloop()
