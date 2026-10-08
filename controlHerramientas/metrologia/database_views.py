import os
import sqlite3
from django.conf import settings
from django.db import connection
from django.http import JsonResponse, HttpResponse
from rest_framework.decorators import api_view, permission_classes, parser_classes
from rest_framework.parsers import MultiPartParser, FormParser
import pandas as pd
import io
from rest_framework.permissions import AllowAny
import numpy as np

@api_view(['GET'])
@permission_classes([AllowAny])
def list_tables(request):
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
            tables = cursor.fetchall()
            
            result = []
            for table in tables:
                table_name = table[0]
                if not table_name.startswith('sqlite_'):
                    cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
                    count = cursor.fetchone()[0]
                    result.append({'name': table_name, 'rows': count})
            
        return JsonResponse({'tables': result})
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@api_view(['GET'])
@permission_classes([AllowAny])
def explore_table(request, table_name):
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name=%s", [table_name])
            if not cursor.fetchone():
                return JsonResponse({'error': 'Table not found'}, status=404)
            
            page = int(request.GET.get('page', 1))
            limit = int(request.GET.get('limit', 50))
            offset = (page - 1) * limit
            
            search = request.GET.get('search', '')
            
            cursor.execute(f"PRAGMA table_info({table_name})")
            columns = [row[1] for row in cursor.fetchall()]
            
            where_clause = ""
            params = []
            if search:
                search_conditions = []
                for col in columns:
                    search_conditions.append(f"{col} LIKE %s")
                    params.append(f"%{search}%")
                where_clause = "WHERE " + " OR ".join(search_conditions)
                
            cursor.execute(f"SELECT COUNT(*) FROM {table_name} {where_clause}", params)
            total_rows = cursor.fetchone()[0]
            
            query = f"SELECT * FROM {table_name} {where_clause} LIMIT {limit} OFFSET {offset}"
            cursor.execute(query, params)
            rows = cursor.fetchall()
            
            data = []
            for row in rows:
                data.append(dict(zip(columns, row)))
                
        return JsonResponse({
            'table': table_name,
            'columns': columns,
            'data': data,
            'total': total_rows,
            'page': page,
            'limit': limit
        })
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@api_view(['GET'])
@permission_classes([AllowAny])
def table_schema(request, table_name):
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name=%s", [table_name])
            if not cursor.fetchone():
                return JsonResponse({'error': 'Table not found'}, status=404)
                
            cursor.execute(f"PRAGMA table_info({table_name})")
            columns_info = cursor.fetchall()
            
            schema = []
            for row in columns_info:
                schema.append({
                    'cid': row[0],
                    'name': row[1],
                    'type': row[2],
                    'notnull': bool(row[3]),
                    'dflt_value': row[4],
                    'pk': bool(row[5])
                })
                
        return JsonResponse({'table': table_name, 'schema': schema})
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@api_view(['POST'])
@permission_classes([AllowAny])
def execute_sql(request):
    sql = request.data.get('sql', '').strip()
    if not sql:
        return JsonResponse({'error': 'No SQL query provided'}, status=400)
        
    try:
        with connection.cursor() as cursor:
            cursor.execute(sql)
            
            if sql.upper().startswith('SELECT') or sql.upper().startswith('PRAGMA'):
                columns = [col[0] for col in cursor.description] if cursor.description else []
                rows = cursor.fetchall()
                data = [dict(zip(columns, row)) for row in rows]
                return JsonResponse({'success': True, 'columns': columns, 'data': data})
            else:
                return JsonResponse({
                    'success': True, 
                    'message': 'Query executed successfully',
                    'rowcount': cursor.rowcount
                })
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=400)

@api_view(['POST', 'GET'])
@permission_classes([AllowAny])
def database_maintenance(request):
    action = request.data.get('action') if request.method == 'POST' else request.GET.get('action')
    
    try:
        db_path = settings.DATABASES['default']['NAME']
        
        if action == 'integrity_check':
            with connection.cursor() as cursor:
                cursor.execute("PRAGMA integrity_check")
                result = cursor.fetchone()[0]
                return JsonResponse({'success': True, 'result': result})
                
        elif action == 'vacuum':
            conn = sqlite3.connect(db_path)
            conn.isolation_level = None
            conn.execute("VACUUM")
            conn.close()
            return JsonResponse({'success': True, 'message': 'Database vacuumed successfully'})
            
        elif action == 'stats':
            size_bytes = os.path.getsize(db_path)
            size_mb = round(size_bytes / (1024 * 1024), 2)
            return JsonResponse({
                'success': True,
                'path': str(db_path),
                'size_mb': size_mb,
                'size_bytes': size_bytes
            })
            
        else:
            return JsonResponse({'error': 'Invalid action'}, status=400)
            
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@api_view(['POST'])
@permission_classes([AllowAny])
def clear_system_tables(request):
    try:
        from metrologia.models import Instrumento
        
        # Eliminar todos los instrumentos (esto eliminará en cascada préstamos y mantenimientos asociados)
        count, deletes = Instrumento.objects.all().delete()
            
        return JsonResponse({
            'success': True, 
            'message': 'Catálogo de instrumentos vaciado exitosamente',
            'tables': ['metrologia_instrumento y sus registros vinculados'],
            'deleted_count': count
        })
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@api_view(['GET'])
@permission_classes([AllowAny])
def instrument_template(request):
    try:
        # Crear un DataFrame con las columnas exactas del modelo Instrumento
        columns = [
            'codigo', 'nombre', 'rango', 'modelo', 'serie', 'marca', 
            'frecuencia_control', 'ultima_calibracion', 'vencimiento_calibracion',
            'num_certificado', 'observacion', 'estado', 'unidad_medida'
        ]
        df = pd.DataFrame(columns=columns)
        
        # Opcional: Agregar una fila de ejemplo para guiar al usuario
        df.loc[0] = [
            'INST-001', 'Calibre Pie de Rey', '0-150mm', '500-196-30', '123456', 'Mitutoyo',
            12, '2023-01-01', '2024-01-01', 'CERT-999', 'Ejemplo de observacion', 'APTO', 'mm'
        ]
        
        output = io.BytesIO()
        with pd.ExcelWriter(output, engine='openpyxl') as writer:
            df.to_excel(writer, index=False, sheet_name='Instrumentos')
            
        output.seek(0)
        
        response = HttpResponse(
            output.read(),
            content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        )
        response['Content-Disposition'] = 'attachment; filename="plantilla_instrumentos.xlsx"'
        return response
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@api_view(['POST'])
@permission_classes([AllowAny])
@parser_classes([MultiPartParser, FormParser])
def import_instruments(request):
    try:
        if 'file' not in request.FILES:
            return JsonResponse({'error': 'No se proporcionó ningún archivo'}, status=400)
            
        excel_file = request.FILES['file']
        df = pd.read_excel(excel_file)
        
        # Limpiar NaN o NaT de forma robusta
        df = df.replace({np.nan: None, pd.NA: None})
        df = df.replace(r'^\s*$', None, regex=True)
        
        from metrologia.models import Instrumento
        
        creados = 0
        actualizados = 0
        errores = []
        
        def clean_str(val):
            if val is None or pd.isna(val):
                return None
            s = str(val).strip()
            if s.lower() in ('none', 'nan', 'nat', 'null', ''):
                return None
            return s
            
        def parse_date(val):
            s = clean_str(val)
            if not s:
                return None
            try:
                return pd.to_datetime(s).date()
            except:
                return None
                
        for index, row in df.iterrows():
            try:
                codigo = clean_str(row.get('codigo'))
                if not codigo:
                    errores.append(f"Fila {index+2}: Falta código de instrumento.")
                    continue
                    
                nombre = clean_str(row.get('nombre'))
                if not nombre:
                    errores.append(f"Fila {index+2}: Falta nombre de instrumento ({codigo}).")
                    continue
                
                frec_control = clean_str(row.get('frecuencia_control'))
                if frec_control:
                    try:
                        frec_control = int(float(frec_control))
                    except:
                        frec_control = None
                        
                defaults = {
                    'nombre': nombre,
                    'rango': clean_str(row.get('rango')),
                    'modelo': clean_str(row.get('modelo')),
                    'serie': clean_str(row.get('serie')),
                    'marca': clean_str(row.get('marca')),
                    'frecuencia_control': frec_control,
                    'ultima_calibracion': parse_date(row.get('ultima_fecha_control') if 'ultima_fecha_control' in row else row.get('ultima_calibracion')),
                    'vencimiento_calibracion': parse_date(row.get('fecha_vencimiento') if 'fecha_vencimiento' in row else row.get('vencimiento_calibracion')),
                    'num_certificado': clean_str(row.get('num_certificado')),
                    'observacion': clean_str(row.get('observacion')),
                    'estado': clean_str(row.get('estado')) or 'APTO',
                    'unidad_medida': clean_str(row.get('unidadM') if 'unidadM' in row else row.get('unidad_medida')),
                    'fecha_baja': parse_date(row.get('fechaBaja') if 'fechaBaja' in row else row.get('fecha_baja')),
                }
                
                # Crear o actualizar
                obj, created = Instrumento.objects.update_or_create(
                    codigo=codigo,
                    defaults=defaults
                )
                
                if created:
                    creados += 1
                else:
                    actualizados += 1
                    
            except Exception as row_e:
                errores.append(f"Fila {index+2}: Error al procesar {codigo} - {str(row_e)}")
                
        return JsonResponse({
            'success': True,
            'message': f'Importación finalizada. Creados: {creados}, Actualizados: {actualizados}',
            'creados': creados,
            'actualizados': actualizados,
            'errores': errores
        })
        
    except Exception as e:
        return JsonResponse({'error': f'Error procesando archivo: {str(e)}'}, status=500)
