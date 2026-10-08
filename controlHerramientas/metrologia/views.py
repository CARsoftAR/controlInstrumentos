from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from datetime import date
import json
from .models import Instrumento, Prestamo, HistorialCalibracion, SystemConfiguration, Ubicacion, InstrumentAuditLog
from personal.models import Operario
from pathlib import Path
from pathlib import Path
import os
import shutil
from datetime import datetime as dt

def log_audit_event(instrument, action_type, details='', user=None, section_assigned=''):
    try:
        InstrumentAuditLog.objects.create(
            instrument=instrument,
            action_type=action_type,
            performed_by=user if user and user.is_authenticated else None,
            section_assigned=section_assigned,
            details=details
        )
    except Exception as e:
        print(f"Error logging audit event: {e}")

@csrf_exempt
def listar_auditoria(request, codigo):
    try:
        logs = InstrumentAuditLog.objects.filter(instrument_id=codigo).order_by('-timestamp')
        data = []
        for log in logs:
            data.append({
                'id': log.id,
                'action_type': log.action_type,
                'performed_by': log.performed_by.username if log.performed_by else 'Sistema/Usuario Local',
                'section_assigned': log.section_assigned or '',
                'timestamp': log.timestamp.strftime('%Y-%m-%d %H:%M:%S'),
                'details': log.details or ''
            })
        return JsonResponse({'success': True, 'logs': data})
    except Exception as e:
        return JsonResponse({'success': False, 'message': str(e)}, status=500)

@csrf_exempt
def listar_auditoria_global(request):
    try:
        from django.db.models import Q
        import datetime
        from django.utils import timezone
        
        query = InstrumentAuditLog.objects.select_related('instrument', 'performed_by').all().order_by('-timestamp')
        
        # Filtros
        search = request.GET.get('search', '')
        action = request.GET.get('action', '')
        
        if search:
            query = query.filter(
                Q(instrument__codigo__icontains=search) | 
                Q(instrument__nombre__icontains=search) |
                Q(section_assigned__icontains=search)
            )
            
        if action:
            query = query.filter(action_type__icontains=action)
            
        # Contadores rápidos
        today = timezone.now().date()
        movimientos_hoy = InstrumentAuditLog.objects.filter(timestamp__date=today).count()
        
        week_ago = today - datetime.timedelta(days=7)
        movimientos_semana = InstrumentAuditLog.objects.filter(timestamp__date__gte=week_ago).count()
        
        # Limitar resultados para no saturar
        logs = query[:200]
        
        data = []
        for log in logs:
            data.append({
                'id': log.id,
                'codigo_instrumento': log.instrument.codigo,
                'nombre_instrumento': log.instrument.nombre,
                'action_type': log.action_type,
                'performed_by': log.performed_by.username if log.performed_by else 'Sistema/Usuario Local',
                'section_assigned': log.section_assigned or '',
                'timestamp': log.timestamp.strftime('%Y-%m-%d %H:%M:%S'),
                'details': log.details or ''
            })
            
        return JsonResponse({
            'success': True, 
            'logs': data,
            'stats': {
                'hoy': movimientos_hoy,
                'semana': movimientos_semana,
                'total_filtrados': query.count()
            }
        })
    except Exception as e:
        return JsonResponse({'success': False, 'message': str(e)}, status=500)

def listar_instrumentos(request):
    instrumentos = Instrumento.objects.all()
    data = []
    for inst in instrumentos:
        data.append({
            'codigo': inst.codigo,
            'nombre': inst.nombre,
            'rango': inst.rango,
            'modelo': inst.modelo,
            'serie': inst.serie,
            'marca': inst.marca,
            'ubicacion_id': inst.ubicacion_id,
            'ubicacion': inst.ubicacion.nombre if inst.ubicacion else '',
            'frecuencia_control': inst.frecuencia_control,
            'ultima_calibracion': str(inst.ultima_calibracion) if inst.ultima_calibracion else None,
            'vencimiento_calibracion': str(inst.vencimiento_calibracion) if inst.vencimiento_calibracion else None,
            'num_certificado': inst.num_certificado,
            'observacion': inst.observacion,
            'estado': inst.py_estado_real,
            'unidad_medida': inst.unidad_medida,
            'ruta_pdf': inst.ruta_pdf,
        })
    return JsonResponse(data, safe=False)


@csrf_exempt
def dashboard_stats(request):
    from datetime import date
    from django.db.models import Q
    today = date.today()

    categoria = request.GET.get('categoria', '')
    query_base = Instrumento.objects.all()
    if categoria:
        query_base = query_base.filter(nombre__iexact=categoria)

    total = query_base.count()
    
    from django.db.models import Count
    base_counts = dict(query_base.values_list('estado').annotate(c=Count('codigo')))
    
    vencidos_qs = query_base.filter(
        vencimiento_calibracion__isnull=False,
        vencimiento_calibracion__lt=today
    ).exclude(estado__in=['BAJA', 'REPARACION'])
    vencidos_breakdown = dict(vencidos_qs.values_list('estado').annotate(c=Count('codigo')))
    
    distribucion = {}
    for state, count in base_counts.items():
        st = (state or 'SIN DEFINIR').upper()
        if st not in distribucion:
            distribucion[st] = 0
        distribucion[st] += count
        
    vencidos_total = 0
    for state, count in vencidos_breakdown.items():
        st = (state or 'SIN DEFINIR').upper()
        if st in distribucion:
            distribucion[st] -= count
        vencidos_total += count
        
    if 'VENCIDO' not in distribucion:
        distribucion['VENCIDO'] = 0
    distribucion['VENCIDO'] += vencidos_total

    # Filtramos para no enviar estados con 0 a la UI
    distribucion_estados = {k: v for k, v in distribucion.items() if v > 0}

    # Distribucion por categoria LOCAL (filtrada)
    local_nombres_counts = dict(query_base.exclude(estado__in=['BAJA', 'REPARACION']).values_list('nombre').annotate(c=Count('codigo')))
    distribucion_categorias = {str(k).upper(): v for k, v in local_nombres_counts.items() if k}

    # Distribucion por categoria GLOBAL para la barra lateral
    global_nombres_counts = dict(Instrumento.objects.exclude(estado__in=['BAJA', 'REPARACION']).values_list('nombre').annotate(c=Count('codigo')))
    global_categorias = {str(k).upper(): v for k, v in global_nombres_counts.items() if k}

    # Compatibilidad con variables estáticas que esperaba el front antes
    aptos = distribucion_estados.get('APTO', 0)
    en_uso = distribucion_estados.get('EN USO', 0)
    reparacion = distribucion_estados.get('REPARACION', 0)
    baja = distribucion_estados.get('BAJA', 0)
    vencidos = distribucion_estados.get('VENCIDO', 0)

    config = SystemConfiguration.get_config()
    alert_days = config.alert_days_threshold
    
    proximos_data = []
    # Generar proximos_data iterando sobre los que estan activos (y filtrados por categoria)
    for inst in query_base.exclude(estado__in=['BAJA', 'REPARACION']):
        if inst.vencimiento_calibracion:
            vto = inst.vencimiento_calibracion
            if isinstance(vto, str):
                from datetime import datetime
                try:
                    vto = datetime.strptime(vto[:10], '%Y-%m-%d').date()
                except:
                    continue
            dias = (vto - today).days
            # Filtro estricto: Sólo instrumentos a vencer en el futuro dentro del umbral (prohibido pasados)
            if 0 <= dias <= alert_days:
                proximos_data.append({
                    'codigo': inst.codigo,
                    'nombre': inst.nombre,
                    'dias': dias,
                    'fecha': str(vto),
                    'estado': inst.py_estado_real,
                    'is_vencido': dias < 0,
                })
    
    proximos_data.sort(key=lambda x: x['dias'])

    prestamos_activos = Prestamo.objects.filter(fecha_devolucion__isnull=True).count()
    total_operarios = Operario.objects.count()

    return JsonResponse({
        'total_instrumentos': total,
        'instrumentos_aprobados': aptos,
        'instrumentos_vencidos': vencidos,
        'instrumentos_reparacion': reparacion,
        'instrumentos_en_uso': en_uso,
        'instrumentos_baja': baja,
        'prestamos_activos': prestamos_activos,
        'total_operarios': total_operarios,
        'proximos_vencimientos': proximos_data,
        'distribucion_estados': distribucion_estados,
        'distribucion_categorias': distribucion_categorias,
        'global_categorias': global_categorias,
        'alert_days_threshold': alert_days,
    })

def listar_operarios(request):
    data = list(Operario.objects.all().values())
    return JsonResponse(data, safe=False)

def listar_prestamos(request):
    data = list(Prestamo.objects.all().values(
        'id', 'fecha_prestamo', 'fecha_devolucion', 'estado', 'observaciones',
        'instrumento__codigo', 'instrumento__nombre',
        'operario__legajo', 'operario__nombre'
    ))
    return JsonResponse(data, safe=False)

@csrf_exempt
def crear_operario(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            op = Operario.objects.create(
                legajo=data.get('legajo'),
                nombre=data.get('nombre'),
                cargo=data.get('cargo', ''),
                activo=data.get('activo', True)
            )
            return JsonResponse({'success': True, 'legajo': op.legajo})
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
    return JsonResponse({'error': 'Invalid method'}, status=405)

@csrf_exempt
def editar_operario(request, legajo):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            op = Operario.objects.get(legajo=legajo)
            if 'nombre' in data:
                op.nombre = data['nombre']
            if 'cargo' in data:
                op.cargo = data['cargo']
            if 'activo' in data:
                op.activo = data['activo']
            op.save()
            return JsonResponse({'success': True})
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
    return JsonResponse({'error': 'Invalid method'}, status=405)

@csrf_exempt
def eliminar_operario(request, legajo):
    if request.method == 'DELETE':
        try:
            op = Operario.objects.get(legajo=legajo)
            op.delete()
            return JsonResponse({'success': True})
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
    return JsonResponse({'error': 'Invalid method'}, status=405)


@csrf_exempt
def crear_prestamo(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            instrumento = Instrumento.objects.get(codigo=data['codigo_instrumento'])
            
            estado_upper = (instrumento.estado or '').upper()
            if estado_upper not in ['BAJA', 'REPARACION']:
                vto = instrumento.vencimiento_calibracion
                if vto and vto < date.today():
                    estado_upper = 'VENCIDO'
            
            if estado_upper not in ['APTO', 'APROBADO']:
                return JsonResponse({
                    'success': False,
                    'message': f'El instrumento no está apto para préstamo. Estado actual dinámico: {estado_upper}'
                }, status=400)

            operario = Operario.objects.get(legajo=data['legajo_operario'])
            prestamo = Prestamo.objects.create(
                instrumento=instrumento,
                operario=operario,
                observaciones=data.get('observaciones', '')
            )
            # Opcional: Cambiar estado del instrumento a 'EN PRESTAMO'
            estado_anterior = instrumento.estado
            instrumento.estado = 'EN USO'
            instrumento.save()
            
            log_audit_event(
                instrument=instrumento,
                action_type='PRÉSTAMO/SALIDA',
                user=request.user,
                section_assigned=operario.nombre,
                details=f"Préstamo a operario {operario.legajo} - {operario.nombre}. Cambio de estado: {estado_anterior} -> EN USO"
            )
            return JsonResponse({'success': True, 'id': prestamo.id})
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
    return JsonResponse({'error': 'Invalid method'}, status=405)

import json
from django.views.decorators.csrf import csrf_exempt

@csrf_exempt
def crear_instrumento(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            frec = data.get('frecuencia_control')
            frec_val = int(frec) if frec is not None and str(frec).isdigit() else None
            
            inst = Instrumento.objects.create(
                codigo=data.get('codigo'),
                nombre=data.get('nombre'),
                marca=data.get('marca', ''),
                estado=data.get('estado', 'APTO'),
                ultima_calibracion=data.get('ultima_calibracion') or None,
                vencimiento_calibracion=data.get('vencimiento_calibracion') or None,
                rango=data.get('rango', ''),
                modelo=data.get('modelo', ''),
                serie=data.get('serie', ''),
                ubicacion_id=data.get('ubicacion_id') or None,
                frecuencia_control=frec_val,
                num_certificado=data.get('num_certificado', ''),
                observacion=data.get('observacion', ''),
                unidad_medida=data.get('unidad_medida', ''),
                ruta_pdf=data.get('ruta_pdf', None)
            )
            if inst.ultima_calibracion and inst.vencimiento_calibracion:
                HistorialCalibracion.objects.create(
                    instrumento=inst,
                    fecha_calibracion=inst.ultima_calibracion,
                    fecha_vencimiento=inst.vencimiento_calibracion,
                    num_certificado=inst.num_certificado or '',
                    observacion='Registro de calibración inicial'
                )
            log_audit_event(
                instrument=inst,
                action_type='CREACIÓN',
                user=request.user,
                details=f"Instrumento creado con estado {inst.estado}"
            )
            return JsonResponse({'success': True, 'codigo': inst.codigo})
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
    return JsonResponse({'error': 'Invalid method'}, status=405)

@csrf_exempt
def eliminar_instrumento(request, codigo):
    if request.method == 'DELETE':
        try:
            inst = Instrumento.objects.get(codigo=codigo)
            inst.delete()
            return JsonResponse({'success': True})
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
    return JsonResponse({'error': 'Invalid method'}, status=405)

@csrf_exempt
def eliminar_prestamo(request, id):
    if request.method == 'DELETE':
        try:
            prestamo = Prestamo.objects.get(id=id)
            if prestamo.estado == 'ACTIVO':
                prestamo.instrumento.estado = 'APTO'
                prestamo.instrumento.save()
            prestamo.delete()
            return JsonResponse({'success': True})
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
    return JsonResponse({'error': 'Invalid method'}, status=405)

from django.utils import timezone
@csrf_exempt
def devolver_prestamo(request, id):
    if request.method == 'POST':
        try:
            prestamo = Prestamo.objects.get(id=id)
            prestamo.estado = 'DEVUELTO'
            prestamo.fecha_devolucion = timezone.now()
            prestamo.save()
            
            estado_anterior = prestamo.instrumento.estado
            prestamo.instrumento.estado = 'APTO'
            prestamo.instrumento.save()
            
            log_audit_event(
                instrument=prestamo.instrumento,
                action_type='DEVOLUCIÓN',
                user=request.user,
                details=f"Devolución de préstamo por operario {prestamo.operario.legajo}. Estado: {estado_anterior} -> APTO"
            )
            return JsonResponse({'success': True})
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
    return JsonResponse({'error': 'Invalid method'}, status=405)

@csrf_exempt
def editar_instrumento(request, codigo):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            inst = Instrumento.objects.get(codigo=codigo)
            if 'nombre' in data:
                inst.nombre = data['nombre']
            if 'marca' in data:
                inst.marca = data['marca']
            if 'estado' in data:
                inst.estado = data['estado']
            fecha_cal_cambiada = False
            if 'ultima_calibracion' in data:
                val = data['ultima_calibracion']
                nueva_val = val if val else None
                if str(inst.ultima_calibracion) != str(nueva_val):
                    fecha_cal_cambiada = True
                inst.ultima_calibracion = nueva_val
            if 'vencimiento_calibracion' in data:
                val = data['vencimiento_calibracion']
                inst.vencimiento_calibracion = val if val else None
            if 'rango' in data:
                inst.rango = data['rango']
            if 'modelo' in data:
                inst.modelo = data['modelo']
            if 'serie' in data:
                inst.serie = data['serie']
            if 'ubicacion_id' in data:
                inst.ubicacion_id = data['ubicacion_id'] or None
            elif 'ubicacion' in data:
                # Fallback in case old frontend sends it
                inst.ubicacion_id = data['ubicacion'] or None
            if 'frecuencia_control' in data:
                val = data['frecuencia_control']
                inst.frecuencia_control = int(val) if val is not None and str(val).isdigit() else None
            if 'num_certificado' in data:
                inst.num_certificado = data['num_certificado']
            if 'observacion' in data:
                inst.observacion = data['observacion']
            if 'unidad_medida' in data:
                inst.unidad_medida = data['unidad_medida']
            if 'ruta_pdf' in data:
                inst.ruta_pdf = data['ruta_pdf']
            inst.save()
            if fecha_cal_cambiada and inst.ultima_calibracion and inst.vencimiento_calibracion:
                HistorialCalibracion.objects.create(
                    instrumento=inst,
                    fecha_calibracion=inst.ultima_calibracion,
                    fecha_vencimiento=inst.vencimiento_calibracion,
                    num_certificado=inst.num_certificado or '',
                    observacion='Calibración modificada por edición'
                )
                
            detalles_edicion = "Edición de datos del instrumento."
            if 'estado' in data:
                detalles_edicion += f" Nuevo estado: {inst.estado}."
                
            log_audit_event(
                instrument=inst,
                action_type='MODIFICACIÓN',
                user=request.user,
                details=detalles_edicion
            )
            return JsonResponse({'success': True})
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
    return JsonResponse({'error': 'Invalid method'}, status=405)

from django.conf import settings
from rest_framework.decorators import api_view
from django.http import JsonResponse

@api_view(['GET'])
def debug_db_path(request):
    return JsonResponse({
        'db_path': str(settings.DATABASES['default']['NAME'])
    })

@api_view(['POST'])
def crear_backup(request):
    try:
        db_path = settings.DATABASES['default']['NAME']
        db_path_obj = Path(db_path)
        if not os.path.exists(db_path):
            return JsonResponse({'status': 'error', 'message': 'Base de datos no encontrada.'}, status=404)
        backups_dir = settings.BASE_DIR.parent / 'Backups_ABBAMAT'
        os.makedirs(backups_dir, exist_ok=True)
        timestamp = dt.now().strftime('%Y-%m-%d_%H-%M-%S')
        backup_name = f'backup_abbamat_{timestamp}'
        backup_zip_path = backups_dir / f'{backup_name}.zip'
        
        # 1. Crear una copia segura usando el motor nativo de SQLite
        import sqlite3
        import zipfile
        import tempfile
        
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_db_path = os.path.join(temp_dir, db_path_obj.name)
            
            # Conectar a origen y destino para hacer el backup seguro (sin importar bloqueos)
            source_conn = sqlite3.connect(db_path)
            dest_conn = sqlite3.connect(temp_db_path)
            with dest_conn:
                source_conn.backup(dest_conn)
            dest_conn.close()
            source_conn.close()
            
            # 2. Comprimir toda la carpeta (BASE_DIR) en el destino final
            portable_dir = settings.BASE_DIR
            
            with zipfile.ZipFile(backup_zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
                for root, dirs, files in os.walk(portable_dir):
                    # Evitar empaquetar la carpeta de backups si por error está dentro de BASE_DIR
                    if 'Backups_ABBAMAT' in dirs:
                        dirs.remove('Backups_ABBAMAT')
                        
                    for file in files:
                        file_path = os.path.join(root, file)
                        arcname = os.path.relpath(file_path, portable_dir)
                        
                        # Si el archivo es la base de datos, metemos la copia desbloqueada temporal
                        if os.path.abspath(file_path) == os.path.abspath(db_path):
                            zipf.write(temp_db_path, arcname=arcname)
                        else:
                            # Ignorar compilados de python para no inflar backups en desarrollo
                            if not file.endswith('.pyc'):
                                zipf.write(file_path, arcname=arcname)
                
        return JsonResponse({'status': 'success', 'message': f'Backup creado: {backup_name}.zip'})
    except Exception as e:
        import traceback
        trace = traceback.format_exc()
        return JsonResponse({'status': 'error', 'message': f'{str(e)} | Detalles: {trace}'}, status=500)

@api_view(['GET'])
def listar_backups(request):
    try:
        backups_dir = settings.BASE_DIR.parent / 'Backups_ABBAMAT'
        os.makedirs(backups_dir, exist_ok=True)
        files = []
        for f in os.listdir(backups_dir):
            if f.endswith('.zip'):
                path = backups_dir / f
                stat = os.stat(path)
                files.append({
                    'nombre': f,
                    'tamano': stat.st_size,
                    'fecha_creacion': dt.fromtimestamp(stat.st_mtime).strftime('%Y-%m-%d %H:%M:%S')
                })
        files.sort(key=lambda x: x['fecha_creacion'], reverse=True)
        return JsonResponse({'status': 'success', 'backups': files})
    except Exception as e:
        return JsonResponse({'status': 'error', 'message': str(e)}, status=500)

@api_view(['POST'])
def eliminar_backup(request):
    try:
        data = json.loads(request.body)
        filename = data.get('nombre')
        if not filename:
            return JsonResponse({'status': 'error', 'message': 'Falta el nombre del archivo.'}, status=400)
        backups_dir = settings.BASE_DIR.parent / 'Backups_ABBAMAT'
        backup_path = backups_dir / filename
        if os.path.exists(backup_path):
            os.remove(backup_path)
            return JsonResponse({'status': 'success', 'message': 'Backup eliminado correctamente.'})
        else:
            return JsonResponse({'status': 'error', 'message': 'Archivo no encontrado.'}, status=404)
    except Exception as e:
        return JsonResponse({'status': 'error', 'message': str(e)}, status=500)

import zipfile
@api_view(['POST'])
def restaurar_backup(request):
    try:
        data = json.loads(request.body)
        filename = data.get('nombre')
        if not filename:
            return JsonResponse({'status': 'error', 'message': 'Falta el nombre del archivo.'}, status=400)
        backups_dir = settings.BASE_DIR.parent / 'Backups_ABBAMAT'
        backup_path = backups_dir / filename
        if not os.path.exists(backup_path):
            return JsonResponse({'status': 'error', 'message': 'Archivo de backup no encontrado.'}, status=404)
        
        db_path = settings.DATABASES['default']['NAME']
        db_path_obj = Path(db_path)
        
        with zipfile.ZipFile(backup_path, 'r') as zip_ref:
            # Calcular cómo se llama el archivo dentro del zip (ruta relativa al BASE_DIR)
            arcname = os.path.relpath(db_path, settings.BASE_DIR)
            
            # Formatear a separador POSIX (interno de zipfile) por seguridad
            arcname_zip = arcname.replace(os.sep, '/')
            
            if arcname_zip in zip_ref.namelist():
                # Extraemos el archivo temporalmente
                extracted_path = zip_ref.extract(arcname_zip, path=str(settings.BASE_DIR.parent))
                # Movemos y sobrescribimos el original
                shutil.move(extracted_path, db_path)
            else:
                # Fallback por si era un backup antiguo donde solo estaba db.sqlite3 en la raíz
                zip_ref.extract(db_path_obj.name, path=str(db_path_obj.parent))
            
        return JsonResponse({'status': 'success', 'message': 'Base de datos restaurada correctamente.'})
    except Exception as e:
        import traceback
        trace = traceback.format_exc()
        return JsonResponse({'status': 'error', 'message': f'{str(e)} | Detalles: {trace}'}, status=500)

from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from django.http import HttpResponse

def aplicar_estilos_xlsx(ws, columnas_centradas, col_estado):
    # Asegurar que se muestren las cuadrículas en Excel
    ws.views.sheetView[0].showGridLines = True
    
    # Definir tipografías, colores y bordes
    fuente_header = Font(name='Calibri', size=11, bold=True, color='FFFFFF')
    relleno_header = PatternFill(start_color='1F4E78', end_color='1F4E78', fill_type='solid') # Azul oscuro profesional
    alineacion_header = Alignment(horizontal='center', vertical='center', wrap_text=True)
    
    fuente_datos = Font(name='Calibri', size=10)
    alineacion_centro = Alignment(horizontal='center', vertical='center')
    alineacion_izq = Alignment(horizontal='left', vertical='center')
    
    borde_fino = Side(border_style="thin", color="D9D9D9")
    borde_celda = Border(left=borde_fino, right=borde_fino, top=borde_fino, bottom=borde_fino)
    
    # Alto para la cabecera
    ws.row_dimensions[1].height = 28
    
    # Aplicar estilos a cabeceras
    for cell in ws[1]:
        cell.font = fuente_header
        cell.fill = relleno_header
        cell.alignment = alineacion_header
        cell.border = borde_celda
        
    # Aplicar estilos y alineaciones a los datos
    for row in range(2, ws.max_row + 1):
        ws.row_dimensions[row].height = 20
        for col in range(1, ws.max_column + 1):
            cell = ws.cell(row=row, column=col)
            cell.font = fuente_datos
            cell.border = borde_celda
            
            if col in columnas_centradas:
                cell.alignment = alineacion_centro
            else:
                cell.alignment = alineacion_izq

            # Pintar y destacar la columna Estado
            if col == col_estado and cell.value:
                val_upper = str(cell.value).upper()
                if 'APTO' in val_upper or 'ENTREGADO' in val_upper or 'DEVUELTO' in val_upper:
                    cell.font = Font(name='Calibri', size=10, bold=True, color='2E7D32') # Verde
                elif 'VENCIDO' in val_upper or 'NO APTO' in val_upper or 'DEMORADO' in val_upper or 'PRESTADO' in val_upper or 'EN USO' in val_upper:
                    cell.font = Font(name='Calibri', size=10, bold=True, color='C62828') # Rojo
                elif 'REPARACION' in val_upper:
                    cell.font = Font(name='Calibri', size=10, bold=True, color='EF6C00') # Naranja

    # Ajuste automático del ancho de las columnas
    for col in ws.columns:
        max_len = 0
        col_letter = col[0].column_letter
        for cell in col:
            if cell.value:
                # Si el campo tiene saltos de línea, medir la línea más larga
                lineas = str(cell.value).split('\n')
                for linea in lineas:
                    if len(linea) > max_len:
                        max_len = len(linea)
        # Asignar ancho con un margen de seguridad
        ws.column_dimensions[col_letter].width = max(max_len + 4, 12)

@api_view(['GET'])
def exportar_instrumentos_xlsx(request):
    try:
        wb = Workbook()
        ws = wb.active
        ws.title = "Instrumentos"
        
        headers = [
            'Código', 'Instrumento', 'Marca', 'Modelo', 'Nº Serie', 'Rango', 
            'Unidad de Medida', 'Ubicación', 'Frecuencia Control (meses)', 
            'Última Calibración', 'Vencimiento Calibración', 'Nº Certificado', 'Estado', 'Observación'
        ]
        ws.append(headers)
        
        q = request.GET.get('q', '')
        query = Instrumento.objects.all()
        if q:
            from django.db.models import Q
            query = query.filter(
                Q(codigo__icontains=q) |
                Q(nombre__icontains=q) |
                Q(marca__icontains=q) |
                Q(estado__icontains=q)
            )

        today = date.today()
        for inst in query:
            estado_dinamico = inst.estado
            if estado_dinamico and estado_dinamico.upper() not in ['BAJA', 'REPARACION']:
                if inst.vencimiento_calibracion and inst.vencimiento_calibracion < today:
                    estado_dinamico = 'VENCIDO'
                    
            ws.append([
                inst.codigo, inst.nombre, inst.marca or '', inst.modelo or '', 
                inst.serie or '', inst.rango or '', inst.unidad_medida or '', 
                inst.ubicacion or '', inst.frecuencia_control or '', 
                inst.ultima_calibracion or '', inst.vencimiento_calibracion or '', 
                inst.num_certificado or '', estado_dinamico, inst.observacion or ''
            ])
            
        # Columnas a centrar: Código(1), Nº Serie(5), Frecuencia(9), Última Calib(10), Vencimiento(11), Nº Cert(12), Estado(13)
        # Columna de estado: 13
        aplicar_estilos_xlsx(ws, [1, 5, 9, 10, 11, 12, 13], 13)
        
        response = HttpResponse(content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        response['Content-Disposition'] = 'attachment; filename="inventario_instrumentos.xlsx"'
        wb.save(response)
        return response
    except Exception as e:
        return JsonResponse({'status': 'error', 'message': str(e)}, status=500)

@api_view(['GET'])
def exportar_prestamos_xlsx(request):
    try:
        wb = Workbook()
        ws = wb.active
        ws.title = "Préstamos"
        
        headers = [
            'ID', 'Código Instrumento', 'Nombre Instrumento', 
            'Legajo Operario', 'Nombre Operario', 
            'Fecha Préstamo', 'Fecha Devolución', 'Estado', 'Observaciones'
        ]
        ws.append(headers)
        
        q = request.GET.get('q', '')
        query = Prestamo.objects.select_related('instrumento', 'operario').all()
        if q:
            from django.db.models import Q
            query = query.filter(
                Q(operario__nombre__icontains=q) |
                Q(operario__apellido__icontains=q) |
                Q(instrumento__codigo__icontains=q) |
                Q(instrumento__nombre__icontains=q) |
                Q(estado__icontains=q)
            )

        for p in query:
            f_prestamo = p.fecha_prestamo.strftime('%Y-%m-%d %H:%M:%S') if p.fecha_prestamo else ''
            f_devolucion = p.fecha_devolucion.strftime('%Y-%m-%d %H:%M:%S') if p.fecha_devolucion else ''
            ws.append([
                p.id, p.instrumento.codigo, p.instrumento.nombre,
                p.operario.legajo, p.operario.nombre,
                f_prestamo, f_devolucion, p.estado, p.observaciones or ''
            ])
            
        # Columnas a centrar: ID(1), Código Instrumento(2), Legajo(4), Fecha Prestamo(6), Fecha Devolucion(7), Estado(8)
        # Columna de estado: 8
        aplicar_estilos_xlsx(ws, [1, 2, 4, 6, 7, 8], 8)
        
        response = HttpResponse(content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        response['Content-Disposition'] = 'attachment; filename="historial_prestamos.xlsx"'
        wb.save(response)
        return response
    except Exception as e:
        return JsonResponse({'status': 'error', 'message': str(e)}, status=500)

@api_view(['GET'])
def listar_historial_calibracion(request, codigo):
    try:
        calibs = HistorialCalibracion.objects.filter(instrumento_id=codigo).order_by('-fecha_calibracion')
        data = []
        for c in calibs:
            data.append({
                'id': c.id,
                'fecha_calibracion': c.fecha_calibracion.strftime('%Y-%m-%d'),
                'fecha_vencimiento': c.fecha_vencimiento.strftime('%Y-%m-%d'),
                'num_certificado': c.num_certificado or '',
                'observacion': c.observacion or '',
                'fecha_registro': c.fecha_registro.strftime('%Y-%m-%d %H:%M:%S')
            })
        return JsonResponse({'success': True, 'historial': data})
    except Exception as e:
        return JsonResponse({'success': False, 'message': str(e)}, status=500)

@api_view(['POST'])
def crear_historial_calibracion(request, codigo):
    try:
        data = json.loads(request.body)
        fecha_cal = data.get('fecha_calibracion')
        fecha_ven = data.get('fecha_vencimiento')
        num_cert = data.get('num_certificado', '')
        obs = data.get('observacion', '')
        
        if not fecha_cal or not fecha_ven:
            return JsonResponse({'success': False, 'message': 'Faltan fechas obligatorias'}, status=400)
            
        inst = Instrumento.objects.get(codigo=codigo)
        
        c = HistorialCalibracion.objects.create(
            instrumento=inst,
            fecha_calibracion=fecha_cal,
            fecha_vencimiento=fecha_ven,
            num_certificado=num_cert,
            observacion=obs
        )
        
        inst.ultima_calibracion = fecha_cal
        inst.vencimiento_calibracion = fecha_ven
        inst.num_certificado = num_cert
        
        if inst.estado in ['VENCIDO', 'NO APTO']:
            inst.estado = 'APTO'
            
        inst.save()
        
        log_audit_event(
            instrument=inst,
            action_type='RECERTIFICACIÓN/CALIBRACIÓN',
            user=request.user,
            details=f"Recalibración registrada. Vencimiento actualizado a {fecha_ven}. Certificado: {num_cert}"
        )
        return JsonResponse({'success': True})
    except Instrumento.DoesNotExist:
        return JsonResponse({'success': False, 'message': 'Instrumento no encontrado'}, status=404)
    except Exception as e:
        return JsonResponse({'success': False, 'message': str(e)}, status=500)

@csrf_exempt
def configuracion_view(request):
    config = SystemConfiguration.get_config()
    
    if request.method == 'GET':
        return JsonResponse({
            'alert_days_threshold': config.alert_days_threshold,
            'company_name': config.company_name,
            'plant_name': config.plant_name,
            'reports_base_path': config.reports_base_path,
        })
    elif request.method in ['PUT', 'PATCH']:
        try:
            data = json.loads(request.body)
            if 'alert_days_threshold' in data:
                config.alert_days_threshold = int(data['alert_days_threshold'])
            if 'company_name' in data:
                config.company_name = data['company_name']
            if 'plant_name' in data:
                config.plant_name = data['plant_name']
            if 'reports_base_path' in data:
                config.reports_base_path = data['reports_base_path']
            config.save()
            return JsonResponse({'success': True})
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
            
    return JsonResponse({'error': 'Invalid method'}, status=405)

from rest_framework import viewsets
from .serializers import UbicacionSerializer

class UbicacionViewSet(viewsets.ModelViewSet):
    queryset = Ubicacion.objects.all()
    serializer_class = UbicacionSerializer


@csrf_exempt
def editar_ubicacion(request, id):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            obj = Ubicacion.objects.get(id=id)
            if 'nombre' in data: obj.nombre = data['nombre']
            if 'pasillo' in data: obj.pasillo = data['pasillo']
            if 'estante' in data: obj.estante = data['estante']
            if 'observaciones' in data: obj.observaciones = data['observaciones']
            obj.save()
            return JsonResponse({'success': True})
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
    return JsonResponse({'error': 'Invalid method'}, status=405)

@csrf_exempt
def eliminar_ubicacion(request, id):
    if request.method == 'DELETE':
        try:
            obj = Ubicacion.objects.get(id=id)
            obj.delete()
            return JsonResponse({'success': True})
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
    return JsonResponse({'error': 'Invalid method'}, status=405)
