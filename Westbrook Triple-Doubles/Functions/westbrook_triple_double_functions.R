plotInGameStatsVsPointDiff <- function(dt) {

  in_game_statistics <- getListOfInGameStatistics()
  
  dt %>% 
    .[, mget(c("Point Difference", "Won?", in_game_statistics))] %>% 
    melt(id.vars = c("Point Difference", "Won?"), measure.vars = in_game_statistics) %>% 
    ggplot(aes(x = value, y = `Point Difference`)) +
    geom_point(aes(color = ifelse(`Won?`, "Won", "Lost"))) +
    facet_wrap(~variable, scales = "free_x", ncol = 5) +
    geom_smooth(method = "lm") +
    labs(title = "Russ' in game stats vs. final point difference",
         subtitle = "Based on the '16-17 and '17-18 regular seasons",
         x     = "") +
    scale_color_manual(values = c("Lost" = "#EF3B24", "Won" = "#007AC1")) +
    theme_minimal() +
    theme(text          = element_text(size = 11, family = "OCR A Extended")) +
    theme(plot.title    = element_text(size = 20),
          plot.caption  = element_text(color = "gray60")) +
    theme(legend.position = "none")
  
  ggsave(
    filename = "Westbrook Triple-Doubles/Figures/westbrook_in_game_stats_vs_point_difference.png",
    device = "png", 
    dpi = 600, 
    width = 10, 
    height = 10
  )
}


getListOfInGameStatistics <- function() {
  c("FG",   "FGA", "FG%",  "TRB", "TRB%",
    "3P",   "3PA", "3P%",  "ORB", "ORB%",
    "FT",   "FTA", "FT%",  "DRB", "DRB%",
    "PTS",  "TS%", "USG%", "AST", "TOV")
}

plotWinPctVsPlayerHadTDorNot <- function(won_lost_by_had_td) {
  last_2_yr_avg_win_pct <- data.frame(
    team = c("GSW", "8. seed", "PHX"),
    avg_win_pct = c((58 + 67) / (2 * 82), (47 + 41) / (2 * 82), (21 + 24) / (2 * 82))
  )
  
  td_w    <- won_lost_by_had_td[`Triple-Double` == TRUE][["Won"]]
  td_l    <- won_lost_by_had_td[`Triple-Double` == TRUE][["Lost"]]
  no_td_w <- won_lost_by_had_td[`Triple-Double` == FALSE][["Won"]]
  no_td_l <- won_lost_by_had_td[`Triple-Double` == FALSE][["Lost"]]
  
  data.table(
    `Win%` = c(1:1000) / 1000,
    `No Triple-Double` = dbeta(c(1:1000)/1000, no_td_w, no_td_l),
    `Triple-Double` = dbeta(c(1:1000)/1000, td_w, td_l)
  ) %>% 
    melt(id.vars = "Win%") %>% 
    ggplot(aes(x = `Win%`, y = value, fill = variable)) +
    geom_area(size = 0, position = "dodge") +
    scale_fill_manual(values = c("Triple-Double" = "#002D62", "No Triple-Double" = "#FDBB30")) +
    geom_text(
      data = last_2_yr_avg_win_pct, 
      mapping = aes(x = avg_win_pct, y = 8.5, label = team, color = team), 
      inherit.aes = F, hjust = -.1, family = "OCR A Extended"
    ) +
    geom_vline(
      data = last_2_yr_avg_win_pct, 
      mapping = aes(xintercept = avg_win_pct, color = team),
      linetype = "dotted"
    ) +
    scale_color_manual( 
      values = c("8. seed" = "black", "GSW" = "#FDB927", "PHX" = "#E56020"), 
      guide = FALSE
    ) +
    labs(title = "OKC's win probability distributions if Russ had...",
         subtitle = "Based on the '16-17 and '17-18 regular seasons",
         y = "") +
    theme_minimal() +
    theme(panel.grid.minor = element_blank(),
          panel.grid.major = element_blank(),
          axis.text.y = element_blank()) +
    theme(text          = element_text(size = 10, family = "OCR A Extended")) +
    theme(plot.title    = element_text(size = 18),
          plot.caption  = element_text(color = "gray60")) +
    theme(legend.position = "top",
          legend.title=element_blank())
  
  ggsave(
    filename = "Westbrook Triple-Doubles/Figures/westbrook_win_pct_td_vs_no_td.png",
    device = "png", 
    dpi = 600, 
    width = 10, 
    height = 6
  )
}


flagDoubleTripleQuadrupleDoublesForPlayer_ <- function(dt) {
    dt %>%
        .[, 
            ten_plus_stat_categories := .(rowSums(.SD>=10)),
            .SDcols = c("PTS", "TRB", "AST", "STL", "BLK")
        ] %>%
        .[, `:=`(`Double-Double`    = ten_plus_stat_categories >= 2,
                 `Triple-Double`    = ten_plus_stat_categories >= 3,
                 `Quadruple-Double` = ten_plus_stat_categories >= 4)
        ] %>%
        .[, ten_plus_stat_categories := NULL] #clean-up
}


createBreakdownOfWinLossByTDorNot <- function(dt) {
  dt %>% 
    .[!is.na(`Triple-Double`), .(Games = .N, Won = sum(`Won?`)), by = `Triple-Double`] %>% 
    .[, `:=`(Lost = Games - Won,
             `Win%` = Won / Games)]
}


plotPointDiffVsStatsRegressionCoeffs <- function(dt) {
  in_game_statistics <-   c(
    "FG", "FGA", "3P", "3PA", "ORB", "FT", "FTA", "DRB", "AST", "TOV"
  )
  
  data_for_lm <- dt %>% 
    copy() %>% 
    .[, mget(c("Point Difference", in_game_statistics))] %>%
    .[!is.na(FGA)]
  
  lm_fit <- lm(
    formula = formula("`Point Difference` ~ ."),
    data = data_for_lm
  )
  
  lm_fit$coefficients %>%
    as.data.table(keep.rownames = T) %>%
    setnames(c("Stat", "Value")) %>%
    .[, Stat := gsub("`", "", Stat)] %>%
    .[, Stat := forcats::fct_reorder(Stat, Value)] %>%
    .[Stat != "(Intercept)"] %>%
    ggplot(aes(x = Stat, y = Value)) +
    geom_bar(stat = "identity", aes(fill = ifelse(Value > 0, "pos", "neg"))) +
    scale_fill_manual(values = c("neg" = "#EF3B24", "pos" = "#007AC1")) +
    coord_flip() +
    labs(title = "Value of Russ getting an extra...",
         subtitle = "Based on the '16-17 and '17-18 regular seasons",
         x = "Final score impact",
         y = "") +
    theme_minimal() +
    theme(text          = element_text(size = 11, family = "OCR A Extended")) +
    theme(plot.title    = element_text(size = 18),
          plot.caption  = element_text(color = "gray60")) +
    theme(legend.position = "none")
  
  ggsave(
    filename = "Westbrook Triple-Doubles/Figures/westbrook_in_game_stats_coefficients.png",
    device = "png",
    dpi = 600,
    width = 6,
    height = 4
  )
}

plotASTandTRBDistributions <- function(dt) {

  rbind(
    dt[, .(n = .N, Stat = "AST"), by = .(value = AST)],
    dt[, .(n = -1 * .N, Stat = "TRB"), by = .(value = TRB)]
  ) %>% 
    ggplot(aes(x = value, y = n, fill = Stat)) +
    geom_bar(stat = "identity") +
    scale_fill_manual( 
      values = c("AST" = "#002D62", "TRB" = "#007AC1")
    ) +
    geom_vline(xintercept = 9.525, color = "#EF3B24") +
    geom_text(
      aes(x = 10, y = 25), label = "10+", color = "#EF3B24", 
      family = "OCR A Extended"
    ) +
    labs(
      title = "Distribution of Assits and Total Rebounds for Westbrook",
      subtitle = "Based on the '16-17 and '17-18 regular seasons",
      x = "",
      y = "# of occurences"
    ) +
    coord_flip() +
    scale_x_reverse() +
    scale_y_continuous(
      breaks = c(-20,-10,0,10,20),
      labels = c(20,10,0,10,20),
      limits = c(-25,25)
    ) +
    theme_minimal() +
    theme(panel.grid.minor = element_blank()) +
    theme(text          = element_text(size = 11, family = "OCR A Extended")) +
    theme(plot.title    = element_text(size = 18),
          plot.caption  = element_text(color = "gray60")) +
    theme(legend.position = "right")

  ggsave(
    filename = "Westbrook Triple-Doubles/Figures/westbrook_ast_trb_distributions.png",
    device = "png",
    dpi = 600,
    width = 9,
    height = 7
  )
}