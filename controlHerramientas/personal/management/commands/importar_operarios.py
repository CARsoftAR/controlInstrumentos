import os
import pandas as pd
from django.core.management.base import BaseCommand
from personal.models import Operario

class Command(BaseCommand):
    help = 'Importa operarios desde un archivo Excel'

    def add_arguments(self, parser):
        parser.add_argument(
            '--archivo',
            type=str,
            help='Ruta absoluta al archivo Excel. Por defecto: C:\\Sistemas ABBAMAT\\control_herramientas_PROYECTO\\operarios.xlsx',
            default=r'C:\Sistemas ABBAMAT\control_herramientas_PROYECTO\operarios.xlsx'
        )

    def handle(self, *args, **kwargs):
        file_path = kwargs['archivo']

        if not os.path.exists(file_path):
            self.stdout.write(self.style.ERROR(f'No se encontró el archivo: {file_path}'))
            return

        self.stdout.write(self.style.SUCCESS(f'Leyendo archivo: {file_path}'))
        
        try:
            # El archivo no tiene cabecera, así que asignamos nombres explícitos a las columnas.
            df = pd.read_excel(file_path, header=None, names=['legajo', 'nombre'])
            df = df.fillna('')
        except Exception as e:
            self.stdout.write(self.style.ERROR(f'Error al leer el archivo Excel: {e}'))
            return

        nuevos = 0
        actualizados = 0

        for idx, row in df.iterrows():
            legajo = str(row.get('legajo', '')).strip()
            nombre = str(row.get('nombre', '')).strip()
            
            # Si el legajo está vacío, no podemos hacer mucho porque es único/requerido.
            if not legajo:
                continue

            try:
                obj, created = Operario.objects.update_or_create(
                    legajo=legajo,
                    defaults={'nombre': nombre, 'activo': True}
                )
                if created:
                    nuevos += 1
                else:
                    actualizados += 1
            except Exception as e:
                self.stdout.write(self.style.WARNING(f'Error al procesar el operario {legajo}: {e}'))

        self.stdout.write(self.style.SUCCESS(
            f'Importación finalizada con éxito.\n'
            f'- Operarios nuevos creados: {nuevos}\n'
            f'- Operarios actualizados: {actualizados}'
        ))
        
        total_bd = Operario.objects.count()
        self.stdout.write(self.style.SUCCESS(f'Total de operarios en BD: {total_bd}'))
