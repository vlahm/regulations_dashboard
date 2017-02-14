# Regulations Dashboard

### A scientist-friendly interface to public policy (in development)

This repository includes tools for R programmers to interface with the Federal Register API in order to search and download federal regulations as CSV files.

R scripts contained in repo include:

Tests:
00_exploration.R
01_testing.R

Working version:
regSearch_v1.R

NOTES
1) API key limited to 1000 uses per day. No big now but it will be
2) should replace rbind with rbind.list, or something similar
3) Consider making functions into R package in future


