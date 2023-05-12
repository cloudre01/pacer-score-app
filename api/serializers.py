from rest_framework import serializers
from .models import Score


class ScoreSerializer(serializers.ModelSerializer):
    score = serializers.IntegerField()

    class Meta:
        model = Score
        fields = '__all__'
