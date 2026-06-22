import os
import time
import tkinter as tk
from tkinter import ttk, messagebox
import threading

class SphenisBuilder:
    def __init__(self, root):
        self.root = root
        self.root.title("SphenisOS Build & Flash Tool")
        self.root.geometry("500x450")
        self.root.configure(bg="#2c3e50")

        # Стили
        style = ttk.Style()
        style.theme_use('clam')
        
        # Заголовок
        self.label = tk.Label(root, text="SphenisOS Terminal", fg="#ecf0f1", bg="#2c3e50", font=("Courier", 16, "bold"))
        self.label.pack(pady=10)

        # Поле вывода логов
        self.log_area = tk.Text(root, height=12, width=55, bg="#000000", fg="#2ecc71", font=("Courier", 9))
        self.log_area.pack(pady=10, padx=10)

        # Выбор диска
        self.drive_frame = tk.Frame(root, bg="#2c3e50")
        self.drive_frame.pack(pady=5)
        tk.Label(self.drive_frame, text="Target Drive (e.g. sdb):", fg="#ecf0f1", bg="#2c3e50").pack(side=tk.LEFT)
        self.drive_entry = tk.Entry(self.drive_frame, width=10)
        self.drive_entry.pack(side=tk.LEFT, padx=5)
        self.drive_entry.insert(0, "sdb")

        # Прогресс-бар
        self.progress = ttk.Progressbar(root, orient=tk.HORIZONTAL, length=400, mode='determinate')
        self.progress.pack(pady=10)

        # Кнопка запуска
        self.build_btn = tk.Button(root, text="🔨 BUILD & FLASH", command=self.start_thread, 
                                  bg="#e67e22", fg="white", font=("Arial", 10, "bold"), padx=20)
        self.build_btn.pack(pady=10)

    def log(self, message):
        self.log_area.insert(tk.END, f"> {message}\n")
        self.log_area.see(tk.END)

    def start_thread(self):
        # Запуск в потоке, чтобы GUI не завис
        thread = threading.Thread(target=self.run_process)
        thread.start()

    def run_process(self):
        self.build_btn.config(state=tk.DISABLED)
        self.progress['value'] = 0
        drive = self.drive_entry.get().strip()
        
        try:
            # 1. Компиляция
            self.log("Starting NASM compilation...")
            files = ["boot", "desktop", "sp_menu", "sp_calc", "sppiano", "spspace", "hexview", "kernel"]
            for i, f in enumerate(files):
                self.log(f"Compiling {f}.asm...")
                os.system(f"nasm -f bin {f}.asm -o {f}.bin")
                self.progress['value'] = (i + 1) * 10
                self.root.update_idletasks()

            # 2. Сборка бинарника
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

            # 3. Запись на флешку
            if drive:
                self.log(f"Flashing to /dev/{drive}...")
                self.log("Requires SUDO. Check your terminal if prompted.")
                # Мы используем sudo dd. В реальном GUI лучше gksudo, но dd через os.system сработает
                cmd = f"sudo dd if=sphenis.bin of=/dev/{drive} bs=1M status=progress oflag=sync"
                os.system(cmd)
                self.log("Flash complete!")
            
            self.progress['value'] = 100
            messagebox.showinfo("Success", "SphenisOS is ready!")

        except Exception as e:
            self.log(f"ERROR: {str(e)}")
            messagebox.showerror("Error", f"Something went wrong: {e}")
        
        self.build_btn.config(state=tk.NORMAL)

if __name__ == "__main__":
    root = tk.Tk()
    app = SphenisBuilder(root)
    root.mainloop()
