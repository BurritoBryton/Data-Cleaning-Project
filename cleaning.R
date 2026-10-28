library(tidyverse)
library(rvest)

#create output folders
dir.create("data_raw", showWarnings = FALSE)
dir.create("data_clean", showWarnings = FALSE)
dir.create("plots", showWarnings = FALSE)


#import Terraria data
terraria_url <- "https://terraria.wiki.gg/wiki/Weapons_List"
terraria_page <- read_html(terraria_url)

xml2::write_xml(terraria_page, "data_raw/terraria_weapons.html")

terraria_tables <- html_table(terraria_page, fill = TRUE, convert = FALSE)

#table 1 contains the weapon stats
terraria_raw <- terraria_tables[[1]]
saveRDS(terraria_raw, "data_raw/terraria_weapons_raw.rds")


#import Calamity data from each class page
calamity_urls <- c(Melee = "https://calamitymod.wiki.gg/wiki/Melee_weapons",
  Ranged = "https://calamitymod.wiki.gg/wiki/Ranged_weapons",
  Magic = "https://calamitymod.wiki.gg/wiki/Magic_weapons",
  Summon = "https://calamitymod.wiki.gg/wiki/Summon_weapons",
  Rogue = "https://calamitymod.wiki.gg/wiki/Rogue_weapons",
  Classless = "https://calamitymod.wiki.gg/wiki/Classless_weapons")

calamity_classes <- list()

for (class_name in names(calamity_urls)) {
  url <- calamity_urls[[class_name]]
  page <- read_html(url)
  file_prefix <- paste0("data_raw/calamity_", tolower(class_name))
  
  
  #save the webpage and original tables
  xml2::write_xml(page, paste0(file_prefix, ".html"))
  tables <- html_table(page, fill = TRUE, convert = FALSE)
  saveRDS(tables, paste0(file_prefix, "_tables.rds"))
  
  #identify weapon stats tables by their column names
  weapon_tables <- list()
  
  for (i in seq_along(tables)) {
    headers <- names(tables[[i]])
    
    if (any(str_detect(headers, regex("^Name$", ignore_case = TRUE))) &&
        any(str_detect(headers, regex("^DMG", ignore_case = TRUE)))) {
      weapon_tables[[length(weapon_tables) + 1]] <-
        as_tibble(tables[[i]], .name_repair = "unique")
    }
  }
  
  if (length(weapon_tables) == 0) {
    stop(paste("No weapon stats table found for", class_name))
  }
  
  calamity_classes[[class_name]] <- bind_rows(weapon_tables) |>
    mutate(weapon_class = class_name, source = "Calamity", source_url = url)
}

calamity_raw <- bind_rows(calamity_classes)
saveRDS(calamity_raw, "data_raw/calamity_all_weapons_raw.rds")


#standardize the shared columns
terraria_work <- as_tibble(terraria_raw, .name_repair = "unique") |>
  transmute(weapon_name = Name, weapon_class = `Damage type`,
    damage_raw = Damage, knockback_raw = Knockback,
    crit_raw = `Critical chance`, use_time_raw = `Use time`,
    source = "Terraria", source_url = terraria_url)

#Name...2 contains names; Name...1 contains weapon images
calamity_work <- calamity_raw |>
  transmute(weapon_name = `Name...2`,
    weapon_class,
    damage_raw = DMG,
    knockback_raw = KB,
    crit_raw = Crit,
    use_time_raw = UT,
    source,
    source_url)

#combine sources, remove extra white space, mark blanks as missing
weapons_work <- bind_rows(terraria_work, calamity_work) |>
  mutate(across(where(is.character), ~ na_if(str_squish(.x), "")))


#identify cells containing multiple numbers for review
stats_to_review <- weapons_work |>
  select(source, weapon_name, ends_with("_raw")) |>
  pivot_longer(
    cols = ends_with("_raw"),
    names_to = "stat",
    values_to = "original_value") |>
  filter(str_count(original_value, "[0-9]+\\.?[0-9]*") > 1)

print(stats_to_review, n = Inf, width = Inf)


weapons_clean <- weapons_work |>
  mutate(damage = parse_number(damage_raw, na = c("", "-", "NA")),
    knockback = parse_number(knockback_raw, na = c("", "-", "NA")),
    crit_chance = parse_number(crit_raw, na = c("", "-", "NA")),
    use_time = parse_number(use_time_raw, na = c("", "-", "NA")),
    weapon_class = if_else(
      weapon_class == "-",
      "Unclassified",
      weapon_class))


#check missing numeric values
missing_summary <- weapons_clean |>
  summarise(across(c(damage, knockback, crit_chance, use_time), ~ sum(is.na(.x))))

print(missing_summary)

#check repeated names
#keep Prismatic Breaker entries because their classes differ
duplicate_weapons <- weapons_clean |>
  count(source, weapon_name) |>
  filter(n > 1)

print(duplicate_weapons, n = Inf)


#summarize entries and damage by source and class
weapon_summary <- weapons_clean |>
  group_by(source, weapon_class) |>
  summarise(
    entries = n(),
    missing_damage = sum(is.na(damage)),
    median_damage = if (all(is.na(damage))) {
      NA_real_
    } else {
      median(damage, na.rm = TRUE)
    },
    .groups = "drop")

print(weapon_summary, n = Inf)

#save the cleaned data and summary
write_csv(weapons_clean, "data_clean/weapons_clean.csv")
saveRDS(weapons_clean, "data_clean/weapons_clean.rds")
write_csv(weapon_summary, "data_clean/weapon_summary.csv")


#compare damage for the four shared classes
damage_plot <- weapons_clean |>
  filter(weapon_class %in% c("Melee", "Ranged", "Magic", "Summon"),
    !is.na(damage)) |>
  ggplot(aes(x = source, y = damage, fill = source)) +
  geom_boxplot() +
  facet_wrap(~ weapon_class) +
  scale_y_continuous(
    transform = scales::transform_log1p(),
    breaks = c(0, 10, 100, 1000, 10000),
    labels = c("0", "10", "100", "1,000", "10,000")) +
  labs(
    title = "Weapon Damage in Terraria and Calamity",
    subtitle = "Shared weapon classes; missing damage values excluded",
    x = NULL,
    y = "Listed weapon damage (log1p scale)",
    caption = paste(
      "All panels share the same scale.",
      "Damage alone does not measure overall weapon strength.")) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none", panel.grid.minor = element_blank())

print(damage_plot)

ggsave(
  "plots/weapon_damage_comparison.png",
  plot = damage_plot,
  width = 10,
  height = 7,
  dpi = 300
)