import os
from datetime import datetime
from rembg import remove
import tkinter as tk
from tkinter import filedialog
from PIL import Image, ImageTk


class BackgroundRemover:
    def __init__(self, carpeta_entrada, carpeta_salida):
        self.carpeta_entrada = carpeta_entrada
        self.carpeta_salida = carpeta_salida

    def procesar_img(self):
        hoy = datetime.now().strftime("%Y-%m-%d %H-%M-%S")
        procesar_carpeta = os.path.join(self.carpeta_salida, hoy)
        os.makedirs(procesar_carpeta, exist_ok=True)

        for filename in os.listdir(self.carpeta_entrada):
            if filename.endswith((".png", ".jpg", ".jpeg")):
                input_path = os.path.join(self.carpeta_entrada, filename)
                output_path = os.path.join(procesar_carpeta, filename)
                self._remover_fondo(input_path, output_path)
                self._mover_imgs(input_path, procesar_carpeta)

    def _remover_fondo(self, input_p, output_p):
        with open(input_p, "rb") as inp, open(output_p, "wb") as outp:
            background_output = remove(inp.read())
            outp.write(background_output)

    def _mover_imgs(self, input_p, dest_p):
        originals_folder = os.path.join(dest_p, "originals")
        os.makedirs(originals_folder, exist_ok=True)

        filename = os.path.basename(input_p)
        new_path = os.path.join(originals_folder, filename)
        os.rename(input_p, new_path)


def seleccionar_carpeta():
    carpeta_seleccionada = filedialog.askdirectory()
    carpeta_entrada_entry.delete(0, tk.END)
    carpeta_entrada_entry.insert(0, carpeta_seleccionada)


def procesar_imagenes():
    carpeta_entrada = carpeta_entrada_entry.get()
    carpeta_salida = carpeta_salida_entry.get()
    remover = BackgroundRemover(carpeta_entrada, carpeta_salida)
    remover.procesar_img()
    mostrar_imagenes_resultado(carpeta_salida)


def mostrar_imagenes_resultado(carpeta_salida):
    ventana_resultado = tk.Toplevel(root)
    ventana_resultado.title("Resultado")

    for filename in os.listdir(carpeta_salida):
        if filename.endswith((".png", ".jpg", ".jpeg", ".HEIC")):
            img_original = Image.open(
                os.path.join(carpeta_entrada_entry.get(), filename)
            )
            img_procesada = Image.open(os.path.join(carpeta_salida, filename))

            img_original.thumbnail((300, 300))
            img_procesada.thumbnail((300, 300))

            img_original_tk = ImageTk.PhotoImage(img_original)
            img_procesada_tk = ImageTk.PhotoImage(img_procesada)

            label_original = tk.Label(ventana_resultado, text="Original")
            label_original.pack()
            label_original_img = tk.Label(ventana_resultado, image=img_original_tk)
            label_original_img.pack()

            label_procesada = tk.Label(ventana_resultado, text="Procesada")
            label_procesada.pack()
            label_procesada_img = tk.Label(ventana_resultado, image=img_procesada_tk)
            label_procesada_img.pack()

            label_original_img.image = img_original_tk
            label_procesada_img.image = img_procesada_tk


if __name__ == "__main__":
    root = tk.Tk()
    root.title("Remover Fondo de Imágenes")

    carpeta_entrada_label = tk.Label(root, text="Carpeta de entrada:")
    carpeta_entrada_label.pack()
    carpeta_entrada_entry = tk.Entry(root)
    carpeta_entrada_entry.pack()
    seleccionar_carpeta_button = tk.Button(
        root, text="Seleccionar Carpeta", command=seleccionar_carpeta
    )
    seleccionar_carpeta_button.pack()

    carpeta_salida_label = tk.Label(root, text="Carpeta de salida:")
    carpeta_salida_label.pack()
    carpeta_salida_entry = tk.Entry(root)
    carpeta_salida_entry.pack()

    procesar_button = tk.Button(
        root, text="Procesar Imágenes", command=procesar_imagenes
    )
    procesar_button.pack()

    root.mainloop()
