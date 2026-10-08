import os
import sys
import django
import pandas as pd
from datetime import datetime

# Configurar entorno de Django
# Asegurarnos de que estamos en el directorio correcto o añadimos el path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from metrologia.models import Instrumento

def importar():
    file_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'INSTRUMENTOSMEDICION.xlsx')
    
    print(f"Leyendo archivo: {file_path}")
    df = pd.read_excel(file_path)
    df = df.fillna('')

    nuevos = 0
    actualizados = 0

    for idx, row in df.iterrows():
        codigo = str(row.get('codigo', '')).strip()
        if not codigo:
            continue
            
        def clean_date(val):
            if pd.isna(val) or val == '':
                return None
            if isinstance(val, datetime):
                return val.date()
            if isinstance(val, pd.Timestamp):
                return val.date()
            try:
                return pd.to_datetime(val).date()
            except:
                return None
                
        def clean_int(val):
            try:
                if str(val).strip() == '': return None
                return int(float(val))
            except:
                return None
                
        defaults = {
            'nombre': str(row.get('instrumento', '')).strip(),
            'rango': str(row.get('rango', '')).strip() if row.get('rango', '') else None,
            'modelo': str(row.get('modelo', '')).strip() if row.get('modelo', '') else None,
            'serie': str(row.get('serie', '')).strip() if row.get('serie', '') else None,
            'marca': str(row.get('marca', '')).strip() if row.get('marca', '') else None,
            'ubicacion': str(row.get('ubicacion', '')).strip() if row.get('ubicacion', '') else None,
            'frecuencia_control': clean_int(row.get('frecuencia_control', '')),
            'ultima_calibracion': clean_date(row.get('ultima_fecha_control', '')),
            'vencimiento_calibracion': clean_date(row.get('fecha_vencimiento', '')),
            'num_certificado': str(row.get('num_certificado', '')).strip() if row.get('num_certificado', '') else None,
            'observacion': str(row.get('observacion', '')).strip() if row.get('observacion', '') else None,
            'estado': str(row.get('estado', '')).strip().upper() if row.get('estado', '') else 'APTO',
            'unidad_medida': str(row.get('unidadMedida', '')).strip() if row.get('unidadMedida', '') else None,
        }
        
        # Fecha de baja no tiene un campo directo en el modelo actual. 
        # Se agrega a la observación.
        fb = clean_date(row.get('fechaBaja', ''))
        if fb:
            obs = defaults['observacion'] or ''
            obs = obs + f" (Fecha Baja: {fb})"
            defaults['observacion'] = obs.strip()

        obj, created = Instrumento.objects.update_or_create(
            codigo=codigo,
            defaults=defaults
        )
        if created:
            nuevos += 1
        else:
            actualizados += 1

    print(f"Importación finalizada: {nuevos} instrumentos nuevos creados, {actualizados} actualizados.")
    print(f"Total en BD: {Instrumento.objects.count()}")

if __name__ == '__main__':
    importar()
