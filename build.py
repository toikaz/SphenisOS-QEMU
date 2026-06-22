import os
import time
import tkinter as tk
from tkinter import ttk, messagebox
import threading

class SphenisBuilder:
    def __init__(self, root):
        self.root = root
        self.root.title("SphenisOS Build & Run Tool")
        self.root.geometry("500x400")
        self.root.configure(bg="#2c3e50")

        style = ttk.Style()
        style.theme_use('clam')
        
        self.label = tk.Label(root, text="SphenisOS Terminal", fg="#ecf0f1", bg="#2c3e50", font=("Courier", 16, "bold"))
        self.label.pack(pady=10)

        self.log_area = tk.Text(root, height=12, width=55, bg="#000000", fg="#2ecc71", font=("Courier", 9))
        self.log_area.pack(pady=10, padx=10)

        self.progress = ttk.Progressbar(root, orient=tk.HORIZONTAL, length=400, mode='determinate')
        self.progress.pack(pady=10)

        self.build_btn = tk.Button(root, text="🚀 BUILD & RUN IN QEMU", command=self.start_thread, 
                                   bg="#e67e22", fg="white", font=("Arial", 10, "bold"), padx=20)
        self.build_btn.pack(pady=10)

    def log(self, message):
        self.log_area.insert(tk.END, f"> {message}\n")
        self.log_area.see(tk.END)

    def start_thread(self):
        thread = threading.Thread(target=self.run_process)
        thread.start()

    def run_process(self):
        self.build_btn.config(state=tk.DISABLED)
        self.progress['value'] = 0
        
        try:
            self.log("Starting NASM compilation...")
            files = ["boot", "desktop", "sp_menu", "sp_calc", "sppiano", "spspace", "hexview", "kernel"]
            for i, f in enumerate(files):
                self.log(f"Compiling {f}.asm...")
                os.system(f"nasm -f bin {f}.asm -o {f}.bin")
                self.progress['value'] = (i + 1) * 10
                self.root.update_idletasks()

            self.log("Assembling sphenis.bin...")
            with open("boot.bin", "rb") as f: boot = f.read()
            with open("kernel.bin", "rb") as f: kernel = f.read()
            
            final_data = boot + kernel
            target = 1474560
            if len(final_data) < target:
                final_data += b"\x00" * (target - len(final_data))

            with open("sphenis.bin", "wb") as f:
                f.write(final_data)
            
            self.log("Binary ready (1.44MB).")
            self.progress['value'] = 85
            self.root.update_idletasks()

            self.log("Starting QEMU...")
            cmd = "qemu-system-i386 -drive file=sphenis.bin,format=raw,index=0,media=disk -display sdl"
            os.system(cmd)
            
            self.log("QEMU execution finished.")
            self.progress['value'] = 100
            messagebox.showinfo("Success", "QEMU closed successfully.")

        except Exception as e:
            self.log(f"ERROR: {str(e)}")
            messagebox.showerror("Error", f"Something went wrong: {e}")
        
        self.build_btn.config(state=tk.NORMAL)

if __name__ == "__main__":
    root = tk.Tk()
    app = SphenisBuilder(root)
    root.mainloop()
