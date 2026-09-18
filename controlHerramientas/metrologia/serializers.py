from rest_framework import serializers
from .models import Instrumento, PatronReferencia, ControlCalibracion
from personal.serializers import OperarioSerializer

class InstrumentoSerializer(serializers.ModelSerializer):
    class Meta:
        model = Instrumento
        fields = "__all__"

class PatronReferenciaSerializer(serializers.ModelSerializer):
    class Meta:
        model = PatronReferencia
        fields = "__all__"

class ControlCalibracionSerializer(serializers.ModelSerializer):
    class Meta:
        model = ControlCalibracion
        fields = "__all__"
