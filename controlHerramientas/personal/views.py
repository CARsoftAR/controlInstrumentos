from rest_framework import viewsets
from .models import Operario
from .serializers import OperarioSerializer

class OperarioViewSet(viewsets.ModelViewSet):
    queryset = Operario.objects.all()
    serializer_class = OperarioSerializer
