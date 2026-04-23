import 'dart:io';
import 'package:flutter/material.dart';
import '../visit_data.dart';
import '../tracking_summary.dart';
import 'form_image_attachment.dart';

class FormContext extends ChangeNotifier {
  String? routeTitle;
  String? routeDescription;
  DateTime visitDate = DateTime.now();
  bool dogNotAllowed = false;

  TrackingSummary? trackingSummary;
  List<FormImageAttachment> photoAttachments = [];
  List<Place> places = [];

  Map<String, dynamic> extraData = {};

  int? monthlyThemeKeywordCount;

  /// Zvýší se po [initializeWith], aby se znovu postavily pole závislá na `extraData`.
  int _dataVersion = 0;
  int get dataVersion => _dataVersion;

  /// Soubory nahraných fotek (kompatibilita se starým kódem).
  List<File> get selectedImages =>
      photoAttachments.map((e) => e.file).toList();

  void initializeWith({
    TrackingSummary? summary,
    VisitData? existingVisit,
  }) {
    if (summary != null) {
      trackingSummary = summary;
      visitDate = summary.startTime ?? DateTime.now();
    } else if (existingVisit?.route != null) {
      final reh = TrackingSummary.fromPersistedRoute(existingVisit!.route!);
      if (reh != null) {
        trackingSummary = reh;
        visitDate = reh.startTime ?? visitDate;
      }
    }

    if (existingVisit != null) {
      routeTitle = existingVisit.routeTitle;
      routeDescription = existingVisit.routeDescription;
      visitDate = existingVisit.visitDate ?? DateTime.now();
      dogNotAllowed =
          existingVisit.dogNotAllowed == 'true' || existingVisit.dogNotAllowed == 'on';
      places = List.from(existingVisit.places);
      extraData = Map.from(existingVisit.extraData ?? {});
    }
    monthlyThemeKeywordCount = null;
    _dataVersion++;
    notifyListeners();
  }

  void setMonthlyThemeKeywordCount(int count) {
    if (monthlyThemeKeywordCount == count) return;
    monthlyThemeKeywordCount = count;
    notifyListeners();
  }

  void updateField(String key, dynamic value) {
    switch (key) {
      case 'routeTitle':
        routeTitle = value?.toString();
        break;
      case 'routeDescription':
        routeDescription = value?.toString();
        break;
      case 'visitDate':
        if (value is DateTime) visitDate = value;
        break;
      case 'dogNotAllowed':
        dogNotAllowed = value == true;
        break;
      default:
        extraData[key] = value;
    }
    notifyListeners();
  }

  void replacePhotoAttachments(List<FormImageAttachment> next) {
    photoAttachments = List.from(next);
    notifyListeners();
  }

  void addPhoto(File file, {bool adminBypassPhotoDate = false}) {
    photoAttachments.add(FormImageAttachment(file, adminBypassPhotoDate: adminBypassPhotoDate));
    notifyListeners();
  }

  void removePhoto(File file) {
    photoAttachments.removeWhere((e) => e.file.path == file.path);
    notifyListeners();
  }

  void updatePlaces(List<Place> newPlaces) {
    places = newPlaces;
    notifyListeners();
  }

  void setTrackingSummary(TrackingSummary summary) {
    trackingSummary = summary;
    notifyListeners();
  }
}
