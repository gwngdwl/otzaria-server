/// נורמליזציית טקסט עברי — חולצה מ‑`lib/utils/text/text_manipulation.dart`
/// של האפליקציה לגרסה pure‑Dart (ללא תלויות Flutter/אפליקציה).
///
/// **קריטי לזהות (parity):** אותו קוד נורמליזציה חייב לרוץ גם בבניית האינדקס,
/// גם בלקוח וגם בשרת. השמות והלוגיקה זהים למקור. ראה מפרט §5.2.
library;

/// ניקוד וטעמים (U+0591–U+05C7).
final RegExp _vowelsAndCantillation = RegExp(r'[֑-ׇ]');

/// טעמים בלבד (U+0591–U+05AF).
final RegExp _cantillationOnly = RegExp(r'[֑-֯]');

/// תגיות HTML ו‑entities.
final RegExp _htmlStripper = RegExp(r'<[^>]*>|&[^;]+;');

/// מסיר ניקוד וטעמים (וגם מקפים/פסוקי טעם שמפרידים מילים).
String removeVolwels(String s) {
  s = s.replaceAll('־', ' ').replaceAll('׀', ' ').replaceAll('|', ' ');
  return s.replaceAll(_vowelsAndCantillation, '');
}

/// מסיר טעמים בלבד (שומר ניקוד).
String removeTeamim(String s) => s
    .replaceAll('־', ' ')
    .replaceAll(' ׀', '')
    .replaceAll('ֽ', '')
    .replaceAll('׀', '')
    .replaceAll(_cantillationOnly, '');

/// מסיר תגיות/entities של HTML, עם שמירת רווחים סביב entities של רווח.
String stripHtmlIfNeeded(String text) {
  final withSpaces = text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&thinsp;', ' ')
      .replaceAll('&ensp;', ' ')
      .replaceAll('&emsp;', ' ');
  return withSpaces.replaceAll(_htmlStripper, '');
}

/// נורמליזציה לצורך התאמת מקור (FindRef):
/// מסיר ניקוד, טעמים, גרשיים, סימני פיסוק, ומאחד רווחים.
/// "שו"ע" → "שוע" ; "בְּרֵאשִׁית" → "בראשית".
String normalizeForFindRefMatch(String input) {
  var cleaned = removeTeamim(removeVolwels(input));

  // הרחבת סימון עמוד גמרא — חייב לרוץ לפני הסרת הגרשיים.
  //   "ב."  (נקודה = עמוד א)  →  "ב א"
  //   "ב:"  (נקודתיים = עמוד ב)  →  "ב ב"
  cleaned = cleaned.replaceAllMapped(
    RegExp(r'''(?<![א-ת'"״׳])([א-ת]{1,3})\.(?=\s|$)'''),
    (m) => '${m[1]} א',
  );
  cleaned = cleaned.replaceAllMapped(
    RegExp(r'''(?<![א-ת'"״׳])([א-ת]{1,3}):(?=\s|$)'''),
    (m) => '${m[1]} ב',
  );

  // הסרה מוחלטת של גרשיים — כך מ"ב הופך למב (לא מ ב)
  cleaned = cleaned
      .replaceAll('"', '')
      .replaceAll("'", '')
      .replaceAll('״', '')
      .replaceAll('׳', '');

  cleaned = cleaned.replaceAll(RegExp(r'[^a-zA-Z0-9֐-׿\s]'), ' ');
  cleaned = cleaned.toLowerCase();
  return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
}
