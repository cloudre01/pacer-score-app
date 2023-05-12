from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response
from .models import Score
from .serializers import ScoreSerializer


@api_view(['POST'])
def get_score(request):
    serializer = ScoreSerializer(data=request.data)
    if serializer.is_valid():
        serializer.validated_data['score'] += 1
        serializer.save()
        return Response(serializer.data, status=status.HTTP_200_OK)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
