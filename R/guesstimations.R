library(readr)
library(dplyr)
library(magrittr)
library(ggplot2)

MAX_ANSWER_ALLOWED <- 1.00e153 ## bigger numbers break geom_histogram idk why
IGNORE_QUESTION_PATTERN <- 'What percent of respondents to this survey'
SHORT_NAMES_FPATH <- '../data/short_names.psv'
RESPONSES_FNAME <- '../data/long_dat.csv'
ANSWERS_FNAME <- '../data/answers.psv'
QUESTIONS_COL <- 'short_question'

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

replace_question_with_short_version <- 
  function(dat, short_names_fpath = SHORT_NAMES_FPATH) {
    short_names_df <- read_delim(short_names_fpath, '|')
    dat %>%
      left_join(short_names_df, by = 'question') %>%
      mutate(question = short_question) %>% 
      select(-short_question)
}

read_response_data <- 
  function(fpath, 
           short_names_fpath = SHORT_NAMES_FPATH,
           use_short_names = TRUE,
           max_answer_allowed = MAX_ANSWER_ALLOWED,
           ignore_pattern = IGNORE_QUESTION_PATTERN) {
  dat <- fpath %>%
    read_csv() %>%
    dplyr::filter(!grepl(IGNORE_QUESTION_PATTERN, question)) %>%
    mutate(answer = pmin(answer, max_answer_allowed))
  if (use_short_names) {
    dat %<>% replace_question_with_short_version(short_names_fpath)
  }
  dat
}

read_answers_data <- 
  function(fpath, short_names_fpath = SHORT_NAMES_FPATH,
           use_short_names = TRUE) {
  dat <- read_delim(fpath, delim = '|')
  if (use_short_names) {
    dat %<>% replace_question_with_short_version(short_names_fpath)
  }
  dat
}


USE_SHORT_NAMES <- TRUE

dat <- read_data(RESPONSES_FNAME, use_short_names = USE_SHORT_NAMES)
answers_dat <- read_answers_data(ANSWERS_FNAME)

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


  
