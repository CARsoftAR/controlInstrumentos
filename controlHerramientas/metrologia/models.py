from django.db import models


class Instrumento(models.Model):
    codigo = models.CharField(max_length=50, primary_key=True)
    nombre = models.CharField(max_length=150)  # Mapea a 'instrumento'
    rango = models.CharField(max_length=100, null=True, blank=True)
    modelo = models.CharField(max_length=100, null=True, blank=True)
    serie = models.CharField(max_length=100, null=True, blank=True)
    marca = models.CharField(max_length=100, null=True, blank=True)
    ubicacion = models.CharField(max_length=100, null=True, blank=True)
    frecuencia_control = models.IntegerField(null=True, blank=True)
    ultima_calibracion = models.DateField(null=True, blank=True)  # Mapea a 'ultima_fecha_control'
    vencimiento_calibracion = models.DateField(null=True, blank=True)  # Mapea a 'fecha_vencimiento'
    num_certificado = models.CharField(max_length=100, null=True, blank=True)
    observacion = models.TextField(null=True, blank=True)
    estado = models.CharField(max_length=50, default='APTO')
    unidad_medida = models.CharField(max_length=50, null=True, blank=True)  # Mapea a 'unidadMedida'
    ruta_pdf = models.TextField(null=True, blank=True)

    @property
    def py_estado_real(self):
        if not self.vencimiento_calibracion:
            return self.estado # o el valor por defecto
        # Asegurar comparación segura con la fecha actual
        vto = self.vencimiento_calibracion
        if isinstance(vto, str):
            from datetime import datetime
            try:
                vto = datetime.strptime(vto[:10], '%Y-%m-%d').date()
            except:
                return self.estado
        from datetime import date
        if vto < date.today():
            return 'VENCIDO'
        return self.estado

    def __str__(self):
        return f"{self.codigo} - {self.nombre}"


class Prestamo(models.Model):
    instrumento = models.ForeignKey(Instrumento, on_delete=models.CASCADE, related_name='prestamos')
    operario = models.ForeignKey('personal.Operario', on_delete=models.CASCADE, related_name='prestamos')
    fecha_prestamo = models.DateTimeField(auto_now_add=True)
    fecha_devolucion = models.DateTimeField(null=True, blank=True)
    estado = models.CharField(max_length=20, default='ACTIVO')
    observaciones = models.TextField(null=True, blank=True)

    def __str__(self):
        return f"{self.instrumento.codigo} -> {self.operario.legajo} ({self.estado})"


class HistorialCalibracion(models.Model):
    instrumento = models.ForeignKey(Instrumento, on_delete=models.CASCADE, related_name='calibraciones')
    fecha_calibracion = models.DateField()
    fecha_vencimiento = models.DateField()
    num_certificado = models.CharField(max_length=100, null=True, blank=True)
    observacion = models.TextField(null=True, blank=True)
    fecha_registro = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.instrumento.codigo} - Calib: {self.fecha_calibracion}"

class SystemConfiguration(models.Model):
    alert_days_threshold = models.IntegerField(default=45)
    company_name = models.CharField(max_length=255, default='ABBAMAT')
    plant_name = models.CharField(max_length=255, default='Planta Principal')
    reports_base_path = models.CharField(max_length=500, blank=True, null=True, default='')

    def save(self, *args, **kwargs):
        # Singleton pattern: solo permitir un registro con pk=1
        self.pk = 1
        super().save(*args, **kwargs)

    @classmethod
    def get_config(cls):
        obj, created = cls.objects.get_or_create(pk=1)
        return obj
