suppressMessages(library(dplyr))
db <- src_sqlite("/Volumes/Zeus/mr_sqlite/db")
d <- tbl(db, "mrinfo")
suppressWarnings(d <- as.data.frame(d))
get_protocol <- function(d, namepat=NA, dirpat=NA, ndcm=NA) {
 # study and not bad id
 d <- d[grepl("pet", d$study) & !grepl("304-00-0009|moved", d$dir), ]
 if (! is.na(namepat)) d <- d[ grepl(namepat, d$Name), ]
 if (! is.na(dirpat))  d <- d[ grepl(dirpat, d$dir), ]
 if (! is.na(ndcm))    d <- d[ d$ndcm %in% ndcm, ]
 return(d)
}

# match sbref, get nfunc count, max and min seqno
sbref    <- get_protocol(d, dirpat="SBRef", ndcm=1)
idv_func <- get_protocol(d, namepat="BOLD_x", ndcm=200)
funcs <-
  merge(idv_func, sbref, by=c("sessionname", "id", "Name")) %>%
  filter(seqno.x - seqno.y == 1) %>%
  select(id, sessionname, seqno=seqno.x, Name,
         dir=dir.x, sbref=dir.y, sbref_seqno=seqno.y) %>%
  group_by(id) %>%
  mutate(nfuncs=n(), start_seqno=min(seqno), end_seqno=max(seqno)) %>%
 ungroup %>% arrange(id, seqno)

# match fm
mag   <- get_protocol(d, namepat="gre_field_mapping", ndcm=90)
phase <- get_protocol(d, namepat="gre_field_mapping", ndcm=45)
fm_match <-
 merge(mag, phase, by=c("id", "sessionname", "patname")) %>%
 filter(abs(seqno.x-seqno.y)==1) %>%
 select(patname, id, sessionname, fmmag=dir.x, fmphase=dir.y,
        magseqno=seqno.x, pahseseqno=seqno.y) %>%
 arrange(patname, magseqno)

fm_func <-
 merge(fm_match, funcs, by=c("sessionname", "id")) %>%
 group_by(sessionname, id, patname) %>%
 mutate(mag_func_dist = abs(magseqno - start_seqno)) %>%
 filter(mag_func_dist == min(mag_func_dist)) %>%
 ungroup %>% arrange(patname, seqno)

all_dirs <-
 fm_func %>%
 mutate(lunaid = substr(patname, 1, 14),
        # ep2d_BOLD_x1_200meas,15 to 1_seq15
        func_num = paste0(substr(Name, 12, 12), "_seq", seqno)) %>%
 select(lunaid, func_num, dir, sbref, fmmag, fmphase)

# remove repeats
all_dirs <- all_dirs[!duplicated(all_dirs$dir), ]

# hard code removing extra 11414_20151107  1_seq10, use 1_seq12 instead
all_dirs <-
 all_dirs %>% filter(!(lunaid=="11414_20151107" & func_num=="1_seq10"))

# print out
write.table(all_dirs, row.names=F, quote=F)

# check (231 on 20180727)
# all_dirs %>% group_by(lunaid) %>% tally %>% filter(n==6) %>% nrow
