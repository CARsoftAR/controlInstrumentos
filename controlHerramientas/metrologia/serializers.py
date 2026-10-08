from rest_framework import serializers
from .models import Instrumento

class InstrumentoSerializer(serializers.ModelSerializer):
    fecha_vencimiento = serializers.DateField(source='vencimiento_calibracion', required=False, allow_null=True)
    ultima_fecha_control = serializers.DateField(source='ultima_calibracion', required=False, allow_null=True)
    fechaBaja = serializers.DateField(source='fecha_baja', required=False, allow_null=True)
    instrumento = serializers.CharField(source='nombre', required=False, allow_null=True)
    unidadMedida = serializers.CharField(source='unidad_medida', required=False, allow_null=True)

    class Meta:
        model = Instrumento
        fields = "__all__"

    def validate(self, attrs):
        vto = attrs.get('vencimiento_calibracion')
        estado = attrs.get('estado', self.instance.estado if self.instance else 'APTO')
        if vto:
            from datetime import date
            if vto < date.today():
                if (estado or '').upper() not in ['BAJA', 'REPARACION']:
                    attrs['estado'] = 'VENCIDO'
            else:
                if (estado or '').upper() == 'VENCIDO':
                    attrs['estado'] = 'APTO'
        return attrs

from .models import Ubicacion

class UbicacionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Ubicacion
        fields = "__all__"
