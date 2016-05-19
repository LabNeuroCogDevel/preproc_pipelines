#!/usr/bin/env bats

load funs_src

@test "pick_mrfolder: cannabis t1+2" {
  source sources/cannabis_rest
  r=$(pick_mrfolder 10905_20111212 10905_20111212 axial_mprage_G2_256x192.18)
  [[ $r == "$MRROOT/10905_20111212/axial_mprage_G2_256x192.18" ]]

  r=$(pick_mrfolder 10907_20141215 10907_20141215 Rest_2_768x720.10 .18)
  [[ $r == "$MRROOT/10907_20141215/Rest_2_768x720.10" ]]
}
