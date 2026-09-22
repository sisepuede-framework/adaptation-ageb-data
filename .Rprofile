options(repos = c(CRAN = "https://cloud.r-project.org"))

# INEGI place names carry accents. Without a UTF-8 locale R transliterates them
# to "<U+00E1>" escapes on write, silently corrupting NOM_MUN / NOM_LOC.
if (.Platform$OS.type == "windows") {
  # R >= 4.2 runs in UTF-8 on Windows 10 1903+ and 11; "en_US.UTF-8" is not a
  # Windows locale name. Older builds (Windows Server 2019 is 1809) stay on
  # code page 1252 unless UTF-8 is enabled system-wide.
  if (!isTRUE(l10n_info()[["UTF-8"]])) {
    warning("R is not running in UTF-8 (code page ", l10n_info()$codepage, "). ",
            "Enable \"Beta: Use Unicode UTF-8\" under Region > Administrative > ",
            "Change system locale, or use R >= 4.2 on Windows 10 1903+.",
            call. = FALSE)
  }
} else {
  # Homebrew tools (gdal, proj, gfortran) are required to build/run the
  # spatial stack on macOS.
  if (Sys.info()[["sysname"]] == "Darwin" && dir.exists("/opt/homebrew/bin")) {
    Sys.setenv(PATH = paste("/opt/homebrew/bin", Sys.getenv("PATH"), sep = ":"))
  }
  invisible(Sys.setlocale("LC_ALL", "en_US.UTF-8"))
}
