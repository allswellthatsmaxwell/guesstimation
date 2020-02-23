library(readr)
library(dplyr)
library(magrittr)
library(ggplot2)

MAX_ANSWER_ALLOWED <- 1.00e153 ## bigger numbers break geom_histogram idk why

get_question_stats <- function(dat) {
  dat %>%
    group_by(question) %>%
    summarize(answers = n(), avg_response_value = mean(answer),
              highest_response = max(answer), lowest_response = min(answer))
}

get_group_stats <- function(dat) {
  dat %>%
    dplyr::select(question_group, timestamp) %>%
    dplyr::distinct() %>%
    group_by(question_group) %>%
    dplyr::summarize(surveys_taken = n())
}

read_data <- function(fpath, max_answer_allowed = MAX_ANSWER_ALLOWED) {
  fpath %>%
    read_csv() %>%
    mutate(answer = pmin(answer, max_answer_allowed))
}

RESPONSES_FNAME <- '../data/long_dat.csv'
ANSWERS_FNAME <- '../data/answers.psv'

dat <- read_data(RESPONSES_FNAME)
answers_dat <- read_delim(ANSWERS_FNAME, delim = '|')

questions <- dat %$% unique(question)
question_stats_table <- dat %>% get_question_stats()
group_stats_table <- dat %>% get_group_stats()

groups_to_investigate <- c("Group A", "Group B")
groups_to_predict_for <- c("Group C", "Group D")

invs_dat <- dat %>% dplyr::filter(question_group %in% groups_to_investigate)
pred_dat <- dat %>% dplyr::filter(question_group %in% groups_to_predict_for)


invs_dat %>%
  ggplot(aes(x = answer)) +
  geom_histogram(bins = 15) +
  theme_bw() +
  facet_wrap(~question, scales = "free") +
  geom_vline(data = answers_dat, aes(xintercept = true_answer),
             color = 'red')


  
