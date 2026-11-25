# Watwat Shorts

Un outil Windows en ligne de commande pour assembler des clips en Shorts et Reels verticaux (1080 × 1920, 30 i/s) et incruster des sous-titres en darija marocaine à partir d’un fichier SRT.

## Démarrage

Installez une version de FFmpeg 7.1 ou plus récente avec ffprobe, libx264 et libass. Placez ffmpeg et ffprobe dans le PATH ou renseignez le chemin de ffmpeg.exe avec -FFmpeg. Arial doit être installé pour retrouver le style de sous-titres prévu.

1. Placez vos rushes dans le dossier clips. Nommez-les 01.mp4, 02.mp4, etc. Le script les assemble dans l’ordre alphabétique.
2. Si vous ajoutez des sous-titres, créez un SRT encodé en UTF-8. Les horodatages partent de 00:00 et suivent la durée du montage complet.
3. Depuis PowerShell, dans le dossier du projet, lancez la commande suivante.

```powershell
.\Montage-Shorts.ps1 -Clips .\clips -Subtitles .\darija.srt -Output .\short-final.mp4
```

Le cadrage Fit conserve l’image entière et ajoute des bandes si nécessaire. Utilisez -Framing Fill pour recadrer au centre et remplir l’écran. Le fichier SRT est facultatif. Les clips muets reçoivent une piste silencieuse. Le traitement se fait localement.

Exemple de SRT.

```srt
1
00:00:00,000 --> 00:00:02,000
فين مشيتي البارح؟

2
00:00:02,200 --> 00:00:04,000
مشيت نسول على الكرا.
```

Cette première version assemble les rushes et incruste des sous-titres déjà préparés. La transcription automatique et la traduction sont hors périmètre.
