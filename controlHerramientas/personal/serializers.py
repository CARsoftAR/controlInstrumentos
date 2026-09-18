from rest_framework import serializers
from .models import Operario

class OperarioSerializer(serializers.ModelSerializer):
    class Meta:
        model = Operario
        fields = "__all__"
