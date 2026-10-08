from django.http import HttpResponse, JsonResponse
from django.utils import timezone
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.units import mm
from datetime import date
import io

from .models import Instrumento, HistorialCalibracion, InstrumentAuditLog, SystemConfiguration

# ─────────────────────────────────────────────────────────────────────────────
# Altura reservada por el encabezado (en puntos).  Debe coincidir con el
# topMargin del SimpleDocTemplate para que el contenido nunca se superponga.
# ─────────────────────────────────────────────────────────────────────────────
HEADER_HEIGHT_MM = 38   # mm de espacio que ocupa el encabezado completo
TOP_MARGIN       = HEADER_HEIGHT_MM * mm   # ≈ 107.7 pt
BOTTOM_MARGIN    = 22 * mm
SIDE_MARGIN_A4   = 20 * mm
SIDE_MARGIN_L    = 15 * mm


# ─────────────────────────────────────────────────────────────────────────────
# Función central: dibuja encabezado institucional + pie de página en el canvas.
# Se invoca para TODAS las páginas (onFirstPage y onLaterPages apuntan aquí).
# ─────────────────────────────────────────────────────────────────────────────
def _draw_page_frame(canvas_obj, doc, report_title: str, emission_dt: str):
    """
    Dibuja el encabezado completo y el pie de página sobre el canvas.
    Debe llamarse tanto en onFirstPage como en onLaterPages.

    Parámetros
    ----------
    canvas_obj   : objeto canvas de ReportLab
    doc          : el SimpleDocTemplate activo
    report_title : título específico del reporte (str)
    emission_dt  : cadena de fecha/hora de emisión (str)
    """
    canvas_obj.saveState()

    page_w, page_h = doc.pagesize
    left  = doc.leftMargin
    right = page_w - doc.rightMargin

    # ── Obtener configuración de empresa ──────────────────────────────────────
    try:
        config = SystemConfiguration.get_config()
        company_name = config.company_name or "ABBAMAT"
        plant_name   = config.plant_name   or "Planta Principal"
    except Exception:
        company_name = "ABBAMAT"
        plant_name   = "Planta Principal"

    # ── Línea separadora superior ─────────────────────────────────────────────
    header_top    = page_h - 10 * mm          # Y superior de la zona de encabezado
    header_bottom = page_h - TOP_MARGIN + 4 * mm

    canvas_obj.setStrokeColor(colors.HexColor('#1e3a5f'))
    canvas_obj.setLineWidth(1.5)
    canvas_obj.line(left, header_top, right, header_top)

    # ── Nombre de empresa (grande, negrita) ───────────────────────────────────
    canvas_obj.setFillColor(colors.HexColor('#1e3a5f'))
    canvas_obj.setFont("Helvetica-Bold", 14)
    canvas_obj.drawString(left, header_top - 7 * mm, company_name)

    # ── Planta / subtítulo empresa ────────────────────────────────────────────
    canvas_obj.setFont("Helvetica", 9)
    canvas_obj.setFillColor(colors.HexColor('#4b5563'))
    canvas_obj.drawString(left, header_top - 12 * mm, plant_name)

    # ── Título del reporte (centro) ───────────────────────────────────────────
    canvas_obj.setFont("Helvetica-Bold", 11)
    canvas_obj.setFillColor(colors.HexColor('#111827'))
    canvas_obj.drawCentredString(
        (left + right) / 2,
        header_top - 8 * mm,
        report_title
    )

    # ── Metadatos: fecha de emisión + página (derecha) ────────────────────────
    canvas_obj.setFont("Helvetica", 8)
    canvas_obj.setFillColor(colors.HexColor('#6b7280'))
    canvas_obj.drawRightString(right, header_top - 7 * mm,  f"Emisión: {emission_dt}")
    canvas_obj.drawRightString(right, header_top - 12 * mm, f"Sistema de Gestión de Metrología")

    # ── Línea separadora inferior del encabezado ──────────────────────────────
    canvas_obj.setStrokeColor(colors.HexColor('#d1d5db'))
    canvas_obj.setLineWidth(0.8)
    canvas_obj.line(left, header_bottom, right, header_bottom)

    # ── PIE DE PÁGINA ─────────────────────────────────────────────────────────
    canvas_obj.setStrokeColor(colors.HexColor('#d1d5db'))
    canvas_obj.setLineWidth(0.8)
    canvas_obj.line(left, 15 * mm, right, 15 * mm)

    canvas_obj.setFont("Helvetica", 8)
    canvas_obj.setFillColor(colors.HexColor('#6b7280'))
    canvas_obj.drawString(left, 10 * mm, "Sistema ABBAMAT — Metrología e Inventario")
    canvas_obj.drawRightString(right, 10 * mm, f"Página {doc.page}")

    canvas_obj.restoreState()


# ─────────────────────────────────────────────────────────────────────────────
# Helpers de estilos de párrafo (internos al módulo)
# ─────────────────────────────────────────────────────────────────────────────
def _get_section_style():
    styles = getSampleStyleSheet()
    return ParagraphStyle(
        'SectionStyle',
        parent=styles['Normal'],
        fontSize=11,
        textColor=colors.HexColor('#1f2937'),
        spaceAfter=6,
        spaceBefore=10,
        alignment=0
    )

def _get_cell_style():
    styles = getSampleStyleSheet()
    return ParagraphStyle(
        'CellStyle',
        parent=styles['Normal'],
        fontSize=9,
        textColor=colors.HexColor('#111827'),
        leading=11
    )


# ─────────────────────────────────────────────────────────────────────────────
# 1. FICHA TÉCNICA DE INSTRUMENTO
# ─────────────────────────────────────────────────────────────────────────────
def generar_pdf_ficha_instrumento(request, codigo):
    try:
        inst = Instrumento.objects.get(codigo=codigo)
    except Instrumento.DoesNotExist:
        return JsonResponse({'success': False, 'message': 'Instrumento no encontrado'}, status=404)

    emission_dt  = timezone.now().strftime('%d/%m/%Y %H:%M')
    report_title = f"Ficha Técnica e Historial — {inst.codigo}"

    def _page_callback(c, d):
        _draw_page_frame(c, d, report_title, emission_dt)

    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        rightMargin=SIDE_MARGIN_A4,
        leftMargin=SIDE_MARGIN_A4,
        topMargin=TOP_MARGIN,
        bottomMargin=BOTTOM_MARGIN,
    )
    elements = []
    sec_style  = _get_section_style()
    cell_style = _get_cell_style()

    # ── Detalles Generales ────────────────────────────────────────────────────
    elements.append(Paragraph("<b>Detalles Generales</b>", sec_style))

    data = [
        [Paragraph('Atributo', cell_style), Paragraph('Valor', cell_style)],
        [Paragraph('Código',              cell_style), Paragraph(inst.codigo,                                              cell_style)],
        [Paragraph('Nombre / Descripción',cell_style), Paragraph(inst.nombre,                                              cell_style)],
        [Paragraph('Marca',               cell_style), Paragraph(inst.marca  or '-',                                      cell_style)],
        [Paragraph('Modelo',              cell_style), Paragraph(inst.modelo or '-',                                      cell_style)],
        [Paragraph('Número de Serie',     cell_style), Paragraph(inst.serie  or '-',                                      cell_style)],
        [Paragraph('Rango de Medición',   cell_style), Paragraph(inst.rango  or '-',                                      cell_style)],
        [Paragraph('Unidad de Medida',    cell_style), Paragraph(inst.unidad_medida or '-',                               cell_style)],
        [Paragraph('Estado',              cell_style), Paragraph(inst.estado,                                              cell_style)],
        [Paragraph('Ubicación',           cell_style), Paragraph(inst.ubicacion.nombre if inst.ubicacion else '-',        cell_style)],
        [Paragraph('Frecuencia Control',  cell_style), Paragraph(f"{inst.frecuencia_control} meses" if inst.frecuencia_control else '-', cell_style)],
        [Paragraph('Certificado',         cell_style), Paragraph(inst.num_certificado or '-',                             cell_style)],
        [Paragraph('Última Calibración',  cell_style), Paragraph(str(inst.ultima_calibracion)    if inst.ultima_calibracion    else '-', cell_style)],
        [Paragraph('Vencimiento Cal.',    cell_style), Paragraph(str(inst.vencimiento_calibracion) if inst.vencimiento_calibracion else '-', cell_style)],
    ]

    t = Table(data, colWidths=[160, 310])
    t.setStyle(TableStyle([
        ('BACKGROUND',    (0, 0), (-1,  0), colors.HexColor('#e5e7eb')),
        ('TEXTCOLOR',     (0, 0), (-1,  0), colors.HexColor('#111827')),
        ('FONTNAME',      (0, 0), (-1,  0), 'Helvetica-Bold'),
        ('FONTSIZE',      (0, 0), (-1,  0), 10),
        ('BOTTOMPADDING', (0, 0), (-1,  0), 10),
        ('BACKGROUND',    (0, 1), (-1, -1), colors.white),
        ('ALIGN',         (0, 0), (-1, -1), 'LEFT'),
        ('VALIGN',        (0, 0), (-1, -1), 'TOP'),
        ('GRID',          (0, 0), (-1, -1), 0.8, colors.HexColor('#d1d5db')),
    ]))
    elements.append(t)
    elements.append(Spacer(1, 18))

    # ── Historial de Calibraciones ────────────────────────────────────────────
    elements.append(Paragraph("<b>Historial de Calibraciones</b>", sec_style))
    historial = HistorialCalibracion.objects.filter(instrumento=inst).order_by('-fecha_calibracion')

    if historial.exists():
        h_data = [[
            Paragraph('Fecha Cal.',  cell_style),
            Paragraph('Fecha Vto.', cell_style),
            Paragraph('Certificado',cell_style),
            Paragraph('Observación',cell_style),
        ]]
        for h in historial:
            h_data.append([
                Paragraph(str(h.fecha_calibracion),                          cell_style),
                Paragraph(str(h.fecha_vencimiento) if h.fecha_vencimiento else '-', cell_style),
                Paragraph(h.num_certificado or '-',                          cell_style),
                Paragraph(h.observacion     or '-',                          cell_style),
            ])
        ht = Table(h_data, colWidths=[80, 80, 100, 210], repeatRows=1)
        ht.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#e5e7eb')),
            ('FONTNAME',   (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('GRID',       (0, 0), (-1,-1), 0.8, colors.HexColor('#d1d5db')),
            ('VALIGN',     (0, 0), (-1,-1), 'TOP'),
        ]))
        elements.append(ht)
    else:
        elements.append(Paragraph("No hay calibraciones registradas.", sec_style))

    doc.build(elements, onFirstPage=_page_callback, onLaterPages=_page_callback)
    pdf = buffer.getvalue()
    buffer.close()

    response = HttpResponse(content_type='application/pdf')
    response['Content-Disposition'] = f'attachment; filename="Ficha_{inst.codigo}.pdf"'
    response.write(pdf)
    return response


# ─────────────────────────────────────────────────────────────────────────────
# 2. REPORTE CRÍTICO DE VENCIDOS
# ─────────────────────────────────────────────────────────────────────────────
def generar_pdf_reporte_vencidos(request):
    try:
        emission_dt  = timezone.now().strftime('%d/%m/%Y %H:%M')
        report_title = "Reporte Crítico de Instrumentos Vencidos"

        def _page_callback(c, d):
            _draw_page_frame(c, d, report_title, emission_dt)

        buffer = io.BytesIO()
        doc = SimpleDocTemplate(
            buffer,
            pagesize=landscape(A4),
            rightMargin=SIDE_MARGIN_L,
            leftMargin=SIDE_MARGIN_L,
            topMargin=TOP_MARGIN,
            bottomMargin=BOTTOM_MARGIN,
        )
        elements = []
        cell_style = _get_cell_style()

        # Estilo para fechas/días vencidos (rojo)
        styles = getSampleStyleSheet()
        vto_style = ParagraphStyle(
            'VtoStyle',
            parent=styles['Normal'],
            fontSize=9,
            textColor=colors.HexColor('#991b1b'),
            fontName='Helvetica-Bold',
            leading=11,
        )

        today = date.today()

        vencidos_data = [[
            Paragraph('Fecha Vto.',   cell_style),
            Paragraph('Días Vencido', cell_style),
            Paragraph('Código',       cell_style),
            Paragraph('Nombre / Descripción', cell_style),
            Paragraph('Marca',        cell_style),
            Paragraph('Estado',       cell_style),
        ]]

        instrumentos = (
            Instrumento.objects
            .exclude(estado__in=['BAJA', 'REPARACION'])
            .filter(
                vencimiento_calibracion__isnull=False,
                vencimiento_calibracion__lt=today,
            )
            .order_by('vencimiento_calibracion')
        )

        for inst in instrumentos:
            vto          = inst.vencimiento_calibracion
            dias_pasados = (today - vto).days
            vencidos_data.append([
                Paragraph(str(vto),              vto_style),
                Paragraph(f"{dias_pasados} días", vto_style),
                Paragraph(inst.codigo,            cell_style),
                Paragraph(inst.nombre,            cell_style),
                Paragraph(inst.marca or '-',      cell_style),
                Paragraph(inst.estado,            cell_style),
            ])

        if len(vencidos_data) > 1:
            # Anchos ajustados a landscape A4 (~772 pt útiles - márgenes)
            t = Table(vencidos_data, colWidths=[80, 80, 70, 270, 130, 75], repeatRows=1)
            t.setStyle(TableStyle([
                ('BACKGROUND',    (0, 0), (-1,  0), colors.HexColor('#fee2e2')),
                ('TEXTCOLOR',     (0, 0), (-1,  0), colors.HexColor('#991b1b')),
                ('FONTNAME',      (0, 0), (-1,  0), 'Helvetica-Bold'),
                ('FONTSIZE',      (0, 0), (-1,  0), 10),
                ('BOTTOMPADDING', (0, 0), (-1,  0), 8),
                ('ALIGN',         (0, 0), (-1, -1), 'LEFT'),
                ('VALIGN',        (0, 0), (-1, -1), 'TOP'),
                ('GRID',          (0, 0), (-1, -1), 0.8, colors.HexColor('#d1d5db')),
            ]))
            elements.append(t)
        else:
            elements.append(Paragraph(
                "No se encontraron instrumentos vencidos.",
                _get_section_style()
            ))

        doc.build(elements, onFirstPage=_page_callback, onLaterPages=_page_callback)
        pdf = buffer.getvalue()
        buffer.close()

        response = HttpResponse(content_type='application/pdf')
        response['Content-Disposition'] = 'attachment; filename="Reporte_Vencimientos.pdf"'
        response.write(pdf)
        return response

    except Exception as e:
        import traceback
        traceback.print_exc()
        return HttpResponse(f"Error generando reporte de vencidos: {str(e)}", status=500)


# ─────────────────────────────────────────────────────────────────────────────
# 3. INVENTARIO GENERAL
# ─────────────────────────────────────────────────────────────────────────────
def generar_pdf_inventario(request):
    try:
        from django.db.models import Q
        from datetime import timedelta

        estado = request.GET.get('estado', '')
        search = request.GET.get('search', '')

        titulo_reporte = "Inventario General de Instrumentos"
        if estado:
            titulo_reporte += f" — Estado: {estado}"
        if search:
            titulo_reporte += f" — Búsqueda: {search}"

        emission_dt = timezone.now().strftime('%d/%m/%Y %H:%M')

        def _page_callback(c, d):
            _draw_page_frame(c, d, titulo_reporte, emission_dt)

        buffer = io.BytesIO()
        doc = SimpleDocTemplate(
            buffer,
            pagesize=landscape(A4),
            rightMargin=SIDE_MARGIN_L,
            leftMargin=SIDE_MARGIN_L,
            topMargin=TOP_MARGIN,
            bottomMargin=BOTTOM_MARGIN,
        )
        elements  = []
        cell_style = _get_cell_style()

        # ── Consulta con filtros ──────────────────────────────────────────────
        query = Instrumento.objects.all().order_by('codigo')
        if estado:
            query = query.filter(estado__iexact=estado)
        if search:
            if search.upper() == 'PRÓX. A VENCER':
                config    = SystemConfiguration.objects.first()
                threshold = config.alert_days_threshold if config else 45
                target    = date.today() + timedelta(days=threshold)
                query = query.exclude(estado__in=['BAJA', 'REPARACION']).filter(
                    vencimiento_calibracion__isnull=False,
                    vencimiento_calibracion__lte=target,
                    vencimiento_calibracion__gte=date.today(),
                )
            else:
                query = query.filter(
                    Q(codigo__icontains=search) |
                    Q(nombre__icontains=search) |
                    Q(marca__icontains=search)
                )

        def _fmt_fecha(fecha):
            return fecha.strftime('%d/%m/%Y') if fecha else '-'

        data = [[
            Paragraph('Código',             cell_style),
            Paragraph('Nombre / Descripción', cell_style),
            Paragraph('Marca',              cell_style),
            Paragraph('Modelo',             cell_style),
            Paragraph('Serie',              cell_style),
            Paragraph('Estado',             cell_style),
            Paragraph('Vencimiento',        cell_style),
        ]]

        for inst in query:
            data.append([
                Paragraph(inst.codigo,                          cell_style),
                Paragraph(inst.nombre,                          cell_style),
                Paragraph(inst.marca  or '-',                   cell_style),
                Paragraph(inst.modelo or '-',                   cell_style),
                Paragraph(inst.serie  or '-',                   cell_style),
                Paragraph(inst.estado,                          cell_style),
                Paragraph(_fmt_fecha(inst.vencimiento_calibracion), cell_style),
            ])

        if len(data) > 1:
            t = Table(data, colWidths=[65, 210, 100, 100, 100, 75, 105], repeatRows=1)
            t.setStyle(TableStyle([
                ('BACKGROUND',    (0, 0), (-1,  0), colors.HexColor('#e0f2fe')),
                ('TEXTCOLOR',     (0, 0), (-1,  0), colors.HexColor('#075985')),
                ('FONTNAME',      (0, 0), (-1,  0), 'Helvetica-Bold'),
                ('FONTSIZE',      (0, 0), (-1,  0), 10),
                ('BOTTOMPADDING', (0, 0), (-1,  0), 8),
                ('ALIGN',         (0, 0), (-1, -1), 'LEFT'),
                ('VALIGN',        (0, 0), (-1, -1), 'TOP'),
                ('GRID',          (0, 0), (-1, -1), 0.8, colors.HexColor('#d1d5db')),
            ]))
            elements.append(t)
        else:
            elements.append(Paragraph(
                "No hay instrumentos registrados en el inventario.",
                _get_section_style()
            ))

        doc.build(elements, onFirstPage=_page_callback, onLaterPages=_page_callback)
        pdf = buffer.getvalue()
        buffer.close()

        response = HttpResponse(content_type='application/pdf')
        response['Content-Disposition'] = 'attachment; filename="Inventario_General.pdf"'
        response.write(pdf)
        return response

    except Exception as e:
        import traceback
        traceback.print_exc()
        return HttpResponse(f"Error generando inventario: {str(e)}", status=500)
