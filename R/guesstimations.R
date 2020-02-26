install.packages("kableExtra")

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
QUESTIONS_PER_GROUP <- 9

get_kth_max <- function(dat, k) {
  dat %>%
    group_by(question) %>%
    mutate(rnk = n() - rank(answer)) %>%
    dplyr::filter(rnk == k) %>%
    distinct(question, answer)
}

get_question_stats <- function(dat) {
  second_maxs <- get_kth_max(dat, 2) %>% rename(second_highest_response = answer)
  third_maxs <- get_kth_max(dat, 3) %>% rename(third_highest_response = answer)
  
  dat %>%
    group_by(question) %>%
    summarize(answers = n(), mean_response_value = mean(answer),
              median_response_value = median(answer),
              highest_response = max(answer), lowest_response = min(answer)) %>%
    left_join(second_maxs, by = 'question') %>%
    left_join(third_maxs, by = 'question')
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

get_timestamp_ranks <- function(dat) {
  dat %>%
    group_by(question_group, question) %>% 
    arrange(question_group, question, desc(answer)) %>% 
    mutate(rnk = 1:n()) 
}

prefix_group_name <- function(question, group) {
  paste0(stringr::str_sub(group, -1), ": ", question)
}

make_facetted_histograms_plot <- function(questions_dat, answers_dat) {
  trans <- log10
  answers_dat %<>% 
    dplyr::inner_join(questions_dat %>% distinct(question, question_group),
                      by = "question") %>%
    mutate(question = prefix_group_name(question, question_group))
    
  questions_dat %<>%
    mutate(question = prefix_group_name(question, question_group))
  
  responses_summary <- questions_dat %>%
    get_question_stats()
  
  true_color <- '#BCBF1D'
  mean_color <- '#33B5FF'
  median_color <- 'red'
  lines_dat <- dplyr::bind_rows(
    responses_summary %>% select(question, mean_response_value) %>%
      rename(val = mean_response_value) %>% 
      mutate(kind = "Mean guess"),
    responses_summary %>% select(question, val = median_response_value) %>%
      mutate(kind = "Median guess"),
    answers_dat %>% select(question, val = true_answer) %>%
      mutate(kind = "True value")
  )
  questions_dat %>%
    ggplot(aes(x = (answer))) +
    geom_histogram(bins = 15) +
    theme_bw() +
    facet_wrap(~question, scales = "free", ncol = 3) +
    geom_vline(data = lines_dat, aes(xintercept = (val), color = kind),
               size = 2) +
    #annotation_logticks() +
    scale_x_log10(labels = function(x) ifelse(x >= 10**5 | x < 1, 
                                              format(x, scientific = TRUE),
                                              scales::comma(x))) +
    scale_color_manual(
      values = c("True value" = true_color, "Mean guess" = mean_color, 
                 "Median guess" = median_color)) +
    theme(axis.text.y = element_blank(), legend.title = element_blank()) +
    labs(x = "log10(guess value)", y = "# guesses", 
         title = "Guesses, and how their average values compare to the true value.")
  }

get_comparison_to_others <- function(dat) {
  dat %>%
    inner_join(invs_dat, by = c("question_group", "question"),
               suffix = c("_this", "_other")) %>%
    dplyr::filter(timestamp_this != timestamp_other) 
}


USE_SHORT_NAMES <- TRUE

dat <- read_data(RESPONSES_FNAME, use_short_names = USE_SHORT_NAMES)
answers_dat <- read_answers_data(ANSWERS_FNAME)

groups_to_investigate <- c("Group A", "Group B", "Group C")
groups_to_predict_for <- c("Group D")

invs_dat <- dat %>% dplyr::filter(question_group %in% groups_to_investigate)
pred_dat <- dat %>% dplyr::filter(question_group %in% groups_to_predict_for)

questions_output_table <- invs_dat %>%
  distinct(question, question_group) %>%
  arrange(question_group, question) %>%
  inner_join(read_delim(SHORT_NAMES_FPATH, delim = '|'),  
             by = c("question" = "short_question")) %>%
  mutate(question_group = stringr::str_sub(question_group, -1)) %>%
  select(Question = question.y, `Short name` = question, Group = question_group) %>%
  select(Question, `Short name`, Group)


question_stats_table <- invs_dat %>% 
  get_question_stats() %>%
  left_join(answers_dat, by = "question")
group_stats_table <- dat %>% get_group_stats()

## Are there guessers guessing consistently high or consistently low?
timestamp_ranks <- invs_dat %>% 
  get_timestamp_ranks()

median_ranks <- timestamp_ranks %>%
  group_by(question_group, timestamp) %>%
  dplyr::summarize(median_rank = median(rnk)) %>%
  arrange(median_rank)

median_ranks %>%
  ggplot(aes(x = median_rank)) +
  geom_histogram(bins = 20) +
  theme_bw() +
  facet_wrap(~question_group)

timestamp_ranks %>%
  ggplot(aes(x = timestamp, y = rnk)) +
  geom_point() +
  theme_bw() +
  facet_wrap(~question_group)


comparison_to_others_dat <- invs_dat %>%
  get_comparison_to_others()

plot_comparison_to_others <- function(dat, group) {
  trans <- log10
  dat %>%
    group_by(timestamp_this, question_group, question, answer_this) %>%
    dplyr::summarize(avg_other_answers = median(answer_other)) %>%
    dplyr::filter(question_group == group) %>%
    ggplot(aes(x = question, group = timestamp_this)) +
    geom_line(aes(y = trans(avg_other_answers))) +
    geom_point(aes(y = trans(answer_this)), color = "red") +
    facet_wrap(~timestamp_this, scales = "free_y") +
    labs(title = group) +
    theme_bw() +
    theme(axis.text.y = element_blank(), 
          axis.text.x = element_text(angle = 90, hjust = 1))
}

comparison_plots <- lapply(
  groups_to_investigate,
  function(group) plot_comparison_to_others(
    comparison_to_others_dat, group))

## Next, look into outlier detection & removal / dampening.

## OK, first finding: median is better than mean, due to the potential for
## crazy-high guesses. Alternatively, we could remove or otherwise dampen outliers.
## But taking the straight mean is bad.


facetted_histogram_plot <- invs_dat %>%
  make_facetted_histograms_plot(answers_dat) +
  theme(strip.text = element_text(size = 22),
        axis.text = element_text(size = 18),
        legend.text = element_text(size = 24),
        plot.title = element_text(size = 24),
        axis.title = element_text(size = 24),
        legend.position = "top")

facetted_histogram_plot
