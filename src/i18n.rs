use serde_json::Value;
use std::sync::LazyLock;

static ENGLISH: LazyLock<Value> =
    LazyLock::new(|| serde_json::from_str(include_str!("../assets/locales/en.json")).unwrap());
static GERMAN: LazyLock<Value> =
    LazyLock::new(|| serde_json::from_str(include_str!("../assets/locales/de.json")).unwrap());

pub(crate) fn text(language: &str, key: &str) -> String {
    let catalog = if language == "de" {
        &*GERMAN
    } else {
        &*ENGLISH
    };
    catalog[key]
        .as_str()
        .or_else(|| ENGLISH[key].as_str())
        .unwrap_or(key)
        .into()
}

pub(crate) fn stage(language: &str, stage: &str) -> String {
    let stage = stage.trim();
    if stage.is_empty() {
        return text(language, "connect_starting_stage");
    }
    let key = format!(
        "connect_stage_{}",
        stage.to_ascii_lowercase().replace([' ', '-'], "_")
    );
    let translated = text(language, &key);
    if translated != key {
        return translated;
    }
    stage
        .split(['_', '-', ' '])
        .filter(|word| !word.is_empty())
        .map(|word| {
            let mut letters = word.chars();
            let first = letters.next().unwrap();
            format!("{}{}", first.to_uppercase(), letters.as_str())
        })
        .collect::<Vec<_>>()
        .join(" ")
}

#[cfg(test)]
mod tests {
    #[test]
    fn english_and_german_have_the_same_catalog_keys() {
        let english = super::ENGLISH.as_object().unwrap();
        let german = super::GERMAN.as_object().unwrap();
        assert!(english.keys().eq(german.keys()));
        assert_eq!(
            super::text("de", "dashboard_choose_macros"),
            "Makros auswählen"
        );
        assert_eq!(super::text("de", "wifi"), "WLAN");
    }

    #[test]
    fn startup_stages_are_localized_and_unknown_stages_are_readable() {
        assert_eq!(super::stage("en", "loading_cache"), "Loading cache…");
        assert_eq!(super::stage("de", "loading_cache"), "Cache wird geladen…");
        assert_eq!(super::stage("de", ""), "Warte auf Backend");
        assert_eq!(super::stage("en", "new-stage"), "New Stage");
    }
}
