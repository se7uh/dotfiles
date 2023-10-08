#!/usr/bin/env python

pasang_dotfiles = input("""
Apa kau yakin ingin memasang dotfiles ini? ini akan menghapus dotfiles mu (masih bisa dikembalikan; lihat trash)
""")

print(pasang_dotfiles)

if pasang_dotfiles == "y":
  print("ok")
else:
  print("ok gk jadi")
