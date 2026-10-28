# Data-Cleaning-Project
Data Science 2 data cleaning project. Cleaning terraira wiki and calamity wiki data.


I first had to find the correct tables in the wikis. The main Calamity weapons page returned a navigation table with 99 columns instead of weapon stats. 
I switched to the individual pages for melee, ranged, magic, summon, rogue, and classless weapons. My script identified weapon tables by checking for name and damage columns. 
I saved the original tables and webpage copies so I could refer back to them.

The two wikis used different column names and layouts. Like Terraria used `Damage` while Calamity used `DMG`. 
I renamed matching columns consistently and selected weapon names, classes, damage, knockback, critical chance, and use time. 
I also recorded the source and page URL for each entry. I removed extra spaces and line breaks and converted blank values to `NA`. 
Prices, rarity, and other image based fields were left out of the comparison because their information was not preserved when importing the tables.

Some stats contained numbers mixed with descriptions, such as `20 (Average)`. I converted these into numeric values while keeping the original text in separate columns. 
Three cells contained multiple numbers. For Adamantite Drill and Mythril Chainsaw, I selected the values labeled for Desktop, Console, and Mobile. 
For Freeze Bomb, I selected damage to enemies instead of damage to the user.

I checked for missing values and found 5 missing damage values, 4 missing knockback values, and 208 missing critical chance values. 
I kept missing values as `NA`. These entries are still in the dataset, but missing damage values are excluded from the damage plot and median calculations.

I also checked for repeated weapon names. Prismatic Breaker appeared on both the Calamity melee and ranged pages. I kept both entries because they had different class labels. 
Terraria also had 33 entries with a class listed as `-`. I labeled these `Unclassified` instead of assuming they matched Calamity's `Classless` category.

The combined dataset contains 1,371 weapon–class entries: 603 from Terraria and 768 from Calamity. I saved the cleaned dataset and created a summary table showing entry counts, missing damage values, and median damage by source and class.

Finally, I created boxplots comparing damage for the four shared classes, Magic, Melee, Ranged, and Summon. A few very high values made the original boxes difficult to see, so I used a log1p scale and clearer axis labels. 
The plot shows that Calamity has a wider damage range, but damage alone does not measure overall weapon strength because attack speed and progression stage also matter.

