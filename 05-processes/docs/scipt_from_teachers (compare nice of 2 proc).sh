#!/bin/bash

logFile=/home/vagrant/cpu.log

# Тест форка
log() {
  echo "$1" >> "$logFile"
}

pigz1() {
    log "pigz1 started `date`"
    dd if=/dev/sda2 | nice --19 pigz >/tmp/boot2_1.img.bz2
    log "pigz1 finished `date`"
}

pigz2() {
    log "pigz2 started `date`"
    dd if=/dev/sda2 | nice -20 pigz>/tmp/boot2_2.img.bz2
    log "pigz2 finished `date`"
}

1>&2 pigz1 &
1>&2 pigz2 &
