library(readr)
library(dplyr)
library(magrittr)
library(ggplot2)

RESPONSES_FNAME <- '../data/long_dat.csv'
ANSWERS_FNAME <- '../data/answers.psv'
MAX_ANSWER_ALLOWED <- 1.00e153 ## bigger numbers break geom_histogram idk why
dat <- read_csv(RESPONSES_FNAME)
dat %<>% mutate(answer = pmin(answer, MAX_ANSWER_ALLOWED))

answers_dat <- read_delim(ANSWERS_FNAME, delim = '|')

questions <- dat %$% unique(question)
question_counts_table <- dat %>%
  group_by(question) %>%
  summarize(answers = n())

dat %>%
  ggplot(aes(x = answer)) +
  geom_histogram(bins = 15) +
  theme_bw() +
  facet_wrap(~question, scales = "free") +
  geom_vline(data = answers_dat, aes(xintercept = true_answer),
             color = 'red')

plots <- lapply(questions, function(q) {
  p <- dat %>%
    dplyr::filter(question == q) %>%
    mutate(answer = pmin(answer, )) %>%
    ggplot(aes(x = answer)) +
    geom_histogram() +
    theme_bw()
})

for (p in plots) {
  print(p)
}
  
