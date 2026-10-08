import os
import sys
import django
import pandas as pd

# Configurar entorno de Django
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from personal.models import Operario

def importar():
    file_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'operarios.xlsx')
    
    print(f"Leyendo archivo: {file_path}")
    # El archivo no tiene encabezados, la fila 1 son datos
    df = pd.read_excel(file_path, header=None)
    df = df.fillna('')

    nuevos = 0
    actualizados = 0

    for idx, row in df.iterrows():
        # Asumiendo columna 0 = legajo, columna 1 = nombre
        legajo = str(row.get(0, '')).strip()
        nombre = str(row.get(1, '')).strip()
        
        if not legajo or not nombre:
            continue
            
        obj, created = Operario.objects.update_or_create(
            legajo=legajo,
            defaults={
                'nombre': nombre,
                'activo': True
            }
        )
        if created:
            nuevos += 1
        else:
            actualizados += 1

    print(f"Importación finalizada: {nuevos} operarios nuevos creados, {actualizados} actualizados.")
    print(f"Total en BD: {Operario.objects.count()}")

if __name__ == '__main__':
    importar()
