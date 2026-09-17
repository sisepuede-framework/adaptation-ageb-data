# 01_utils.R -- download caching, key construction and shared readers.

suppressPackageStartupMessages({
  library(dplyr); library(readr); library(stringr); library(tidyr); library(purrr)
})

log_msg <- function(...) {
  cat(sprintf("[%s] %s\n", format(Sys.time(), "%H:%M:%S"), paste0(...)))
  flush.console()
}

log_step <- function(...) log_msg("== ", paste0(...))

# --- Download -------------------------------------------------------------

# INEGI serves missing files as an HTTP 200 HTML page ("Esta liga ya no
# existe"), so status code alone cannot be trusted. Every download is checked
# for size and for an HTML magic prefix before being accepted into the cache.
looks_like_html <- function(path) {
  con <- file(path, "rb"); on.exit(close(con))
  head_bytes <- readBin(con, "raw", n = 16L)
  if (length(head_bytes) == 0) return(TRUE)
  # Compared as raw bytes on purpose: zip payloads are not valid text in any
  # locale, and converting them to a string first makes grepl emit
  # "unable to translate ... to a wide string" warnings on every download.
  starts_with <- function(prefix) {
    b <- charToRaw(prefix)
    length(head_bytes) >= length(b) && all(head_bytes[seq_along(b)] == b)
  }
  starts_with("<!DOCTYPE") || starts_with("<!doctype") ||
    starts_with("<html") || starts_with("<HTML") || starts_with("\n<!DOC")
}

download_cached <- function(url, dest, min_bytes = MIN_DOWNLOAD_BYTES,
                            max_tries = 4L) {
  if (file.exists(dest) && file.size(dest) >= min_bytes) {
    log_msg("cached: ", basename(dest), " (",
            format(structure(file.size(dest), class = "object_size"),
                   units = "auto"), ")")
    return(invisible(dest))
  }
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(dest, ".part")

  for (attempt in seq_len(max_tries)) {
    log_msg("downloading (try ", attempt, "): ", basename(dest))
    # A bare curl_download has no timeout: INEGI transfers do sometimes stall
    # mid-file and would then hang the whole national run forever (observed on
    # a 200 MB entity, frozen for 15 minutes at the same byte count). The
    # low-speed guard aborts anything under 1 KB/s for 60 s so the retry loop
    # can do its job.
    h <- curl::new_handle(
      connecttimeout = 60L,
      low_speed_limit = 1024L,
      low_speed_time = 60L,
      noprogress = TRUE
    )
    ok <- tryCatch({
      curl::curl_download(url, tmp, quiet = TRUE, mode = "wb", handle = h)
      TRUE
    }, error = function(e) { log_msg("  transfer failed: ", conditionMessage(e)); FALSE })

    if (ok && file.exists(tmp)) {
      if (file.size(tmp) < min_bytes || looks_like_html(tmp)) {
        log_msg("  rejected: server returned an error page, not data")
        unlink(tmp)
      } else {
        file.rename(tmp, dest)
        log_msg("  ok: ", format(structure(file.size(dest),
                                           class = "object_size"), units = "auto"))
        return(invisible(dest))
      }
    }
    if (attempt < max_tries) Sys.sleep(2^attempt)
  }
  stop("could not download a valid file from: ", url, call. = FALSE)
}

# True when the URL serves real data. INEGI answers missing files with an HTTP
# 200 HTML page, so the content type is what distinguishes them, not the status.
url_is_data <- function(url) {
  tryCatch({
    h <- curl::new_handle(nobody = TRUE, connecttimeout = 30L, followlocation = TRUE)
    resp <- curl::curl_fetch_memory(url, handle = h)
    ct <- curl::parse_headers_list(resp$headers)[["content-type"]]
    !is.null(ct) && !grepl("text/html", ct, fixed = TRUE)
  }, error = function(e) FALSE)
}

# Unzips once into <dir>/<name>/ and returns that directory on later calls.
unzip_cached <- function(zip_path, out_dir) {
  marker <- file.path(out_dir, ".unzipped")
  if (file.exists(marker)) return(invisible(out_dir))
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  log_msg("unzipping: ", basename(zip_path))
  # INEGI archives carry non-UTF-8 file names ("l\u00e9eme.pdf",
  # "15_M\u00e9xico_r15m_v4.tif"). R's internal unzip aborts on them and the
  # system `unzip` hangs on a prompt it cannot show, so bsdtar is used. Left to
  # guess the encoding, bsdtar silently skips those entries -- which once
  # dropped the elevation model of every entity with an accent in its name --
  # so the names are decoded as CP850, the DOS code page the archives use.
  opts <- c("--options", "zip:hdrcharset=CP850")
  suppressWarnings(system2("tar",
    c("-xf", shQuote(zip_path), opts, "-C", shQuote(out_dir)),
    stdout = FALSE, stderr = FALSE))
  # Every file entry must land on disk; a count is enough to catch a skip.
  listed <- suppressWarnings(system2("tar", c("-tf", shQuote(zip_path), opts),
                                     stdout = TRUE, stderr = FALSE))
  n_listed <- sum(!grepl("/$", listed))
  n_found <- length(list.files(out_dir, recursive = TRUE, all.files = TRUE))
  if (n_found == 0 || n_found < n_listed) {
    stop("extracted ", n_found, " of ", n_listed, " files from ",
         basename(zip_path), call. = FALSE)
  }
  writeLines(format(Sys.time()), marker)
  invisible(out_dir)
}

# Finds one file inside an extracted archive by regex, erroring on ambiguity.
find_file <- function(dir, pattern, required = TRUE) {
  # Matched against the path relative to `dir`, not just the base name, so a
  # pattern can disambiguate conjunto_de_datos/ from diccionario_de_datos/.
  rel <- list.files(dir, recursive = TRUE, ignore.case = TRUE)
  rel <- rel[!grepl("__MACOSX", rel, fixed = TRUE)]
  hits <- file.path(dir, rel[grepl(pattern, rel, ignore.case = TRUE)])
  if (length(hits) == 0) {
    if (required) stop("no file matching '", pattern, "' under ", dir, call. = FALSE)
    return(NA_character_)
  }
  hits[[1]]
}

# --- Keys (spec section 4) ------------------------------------------------

pad <- function(x, width) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  str_pad(str_trim(x), width = width, side = "left", pad = "0")
}

# ID_AGEB = ENT(2) + MUN(3) + LOC(4) + AGEB(4) = 13 characters.
# CVE_AGEB is alphanumeric, so everything stays character throughout.
build_ageb_id <- function(ent, mun, loc, ageb) {
  paste0(pad(ent, 2), pad(mun, 3), pad(loc, 4), pad(ageb, 4))
}

build_loc_id <- function(ent, mun, loc) {
  paste0(pad(ent, 2), pad(mun, 3), pad(loc, 4))
}

build_mun_id <- function(ent, mun) paste0(pad(ent, 2), pad(mun, 3))

# --- Readers --------------------------------------------------------------

# Census and ITER CSVs are UTF-8 (with a BOM on the first header name).
read_utf8_csv <- function(path, ...) {
  read_csv(path, locale = locale(encoding = "UTF-8"),
           col_types = cols(.default = col_character()),
           progress = FALSE, ...)
}

# DENUE CSVs and CONABIO shapefile attributes ship as latin-1.
read_latin1_csv <- function(path, ...) {
  read_csv(path, locale = locale(encoding = "latin1"),
           col_types = cols(.default = col_character()),
           progress = FALSE, ...)
}

# Census suppression markers become NA rather than zero (spec section 5.2).
to_num_suppressed <- function(x) {
  x <- as.character(x)
  x[str_trim(x) %in% c("*", "N/D", "N/A", "", "-")] <- NA_character_
  suppressWarnings(as.numeric(x))
}

safe_pct <- function(num, den) ifelse(is.na(den) | den == 0, NA_real_, 100 * num / den)

safe_ratio <- function(num, den) ifelse(is.na(den) | den == 0, NA_real_, num / den)

interim_path <- function(name, ent, ext = "rds") {
  file.path(DIR_INTERIM, sprintf("%s_%s.%s", name, ent, ext))
}
