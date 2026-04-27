import 'package:flutter/material.dart';
import 'tag_style_repository.dart';

const String appleOffensiveTag = 'MANZANA';
const String nerdSecretTag = 'NERD';
const String betaTesterTag = 'BETA TESTER';
const String ghostTag = 'FANTASMA';
const String addictTag = 'ADICTO';
const String explorerTag = 'EXPLORADOR';

const secretTags = <String>{
  appleOffensiveTag,
  nerdSecretTag,
  betaTesterTag,
  ghostTag,
  addictTag,
  explorerTag,
};

const explorerRequiredTags = <String>{
  appleOffensiveTag,
  nerdSecretTag,
  betaTesterTag,
  ghostTag,
  addictTag,
};

String normalizeTagKey(String tag) => tag.trim().toUpperCase();

bool isSecretTag(String tag) => secretTags.contains(normalizeTagKey(tag));

bool isAppleOffensiveTag(String tag) =>
    normalizeTagKey(tag) == appleOffensiveTag;

bool isNerdSecretTag(String tag) => normalizeTagKey(tag) == nerdSecretTag;

bool isBetaTesterTag(String tag) => normalizeTagKey(tag) == betaTesterTag;

bool isGhostTag(String tag) => normalizeTagKey(tag) == ghostTag;

bool isAddictTag(String tag) => normalizeTagKey(tag) == addictTag;

bool isExplorerTag(String tag) => normalizeTagKey(tag) == explorerTag;

String displayTagLabel(String tag) {
  switch (normalizeTagKey(tag)) {
    case appleOffensiveTag:
      return 'Antisemita';
    case nerdSecretTag:
      return 'NERD';
    case betaTesterTag:
      return 'BETA TESTER';
    case ghostTag:
      return 'FANTASMA';
    case addictTag:
      return 'ADICTO';
    case explorerTag:
      return 'EXPLORADOR';
    default:
      return tag.trim();
  }
}

TagStyle secretTagStyle(String tag) {
  switch (normalizeTagKey(tag)) {
    case appleOffensiveTag:
      return const TagStyle(
        bg: Colors.white,
        text: Color(0xFF0057B8),
        holo: false,
      );

    case nerdSecretTag:
      return const TagStyle(
        bg: Colors.black,
        text: Color(0xFF39FF14),
        holo: false,
      );

    case betaTesterTag:
      return const TagStyle(
        bg: Color(0xFF191919),
        text: Color(0xFFFFD54F),
        holo: false,
      );

    case ghostTag:
      return const TagStyle(
        bg: Color(0x55222222),
        text: Color(0xFFECEFF1),
        holo: false,
      );

    case addictTag:
      return const TagStyle(
        bg: Color(0xFF2A1010),
        text: Color(0xFFFFC46B),
        holo: false,
      );

    case explorerTag:
      return const TagStyle(
        bg: Color(0xFF3A250B),
        text: Color(0xFFFFD36E),
        holo: false,
      );


    default:
      return TagStyle.fallback;
  }
}

TagStyle resolveTagStyle(String tag, Map<String, TagStyle> styles) {
  final clean = tag.trim();
  if (isSecretTag(clean)) return secretTagStyle(clean);
  return styles[clean] ?? TagStyle.fallback;
}