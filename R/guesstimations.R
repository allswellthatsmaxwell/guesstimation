library(readr)
library(dplyr)
library(magrittr)
library(ggplot2)

FNAME <- '../data/long_dat.csv'
dat <- read_csv(FNAME)

questions <- dat %$% unique(question)
dat %>%
  ggplot(aes(x = answer)) +
  geom_histogram() +
  theme_bw() +
  facet_wrap(~question, scales = "free")
