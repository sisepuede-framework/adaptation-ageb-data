options(repos = c(CRAN = "https://cloud.r-project.org"))

# INEGI place names carry accents. Without a UTF-8 locale R transliterates them
# to "<U+00E1>" escapes on write, silently corrupting NOM_MUN / NOM_LOC.
if (.Platform$OS.type == "windows") {
  # R >= 4.2 on Windows runs in UTF-8 natively (UCRT); "en_US.UTF-8" is not a
  # Windows locale name, so the check is all that is needed here.
  if (!isTRUE(l10n_info()[["UTF-8"]])) {
    warning("R is not running in UTF-8: install R >= 4.2 so accented INEGI ",
            "names are written correctly.", call. = FALSE)
  }
} else {
  # Homebrew tools (gdal, proj, gfortran) are required to build/run the
  # spatial stack on macOS.
  if (Sys.info()[["sysname"]] == "Darwin" && dir.exists("/opt/homebrew/bin")) {
    Sys.setenv(PATH = paste("/opt/homebrew/bin", Sys.getenv("PATH"), sep = ":"))
  }
  invisible(Sys.setlocale("LC_ALL", "en_US.UTF-8"))
}
