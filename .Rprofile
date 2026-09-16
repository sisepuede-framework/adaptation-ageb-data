# Homebrew tools (gdal, proj, gfortran) are required to build/run the spatial stack.
Sys.setenv(PATH = paste("/opt/homebrew/bin", Sys.getenv("PATH"), sep = ":"))
options(repos = c(CRAN = "https://cloud.r-project.org"))

# INEGI place names carry accents. Without a UTF-8 locale R transliterates them
# to "<U+00E1>" escapes on write, silently corrupting NOM_MUN / NOM_LOC.
invisible(Sys.setlocale("LC_ALL", "en_US.UTF-8"))
