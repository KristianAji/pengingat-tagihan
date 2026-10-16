package com.pengingattagihan.app.widget

import java.util.Calendar
import java.util.TimeZone

/**
 * Hitungan hari menuju jatuh tempo untuk widget.
 *
 * Dipisah dari [BillWidget] supaya bisa diuji tanpa menjalankan widget-nya —
 * perhitungan tanggal gampang salah di batas hari, dan widget tidak punya
 * cara lain untuk memberi tahu bahwa angkanya keliru.
 *
 * Aturannya PER TANGGAL, bukan per 24 jam: tagihan yang jatuh tempo nanti
 * malam tetap terbaca "Hari ini", bukan "Besok".
 *
 * [zona] sengaja bisa diberikan: tanggal jatuh tempo disimpan sebagai instant
 * absolut (tengah malam waktu lokal saat tagihan dibuat), jadi hari ke-nya
 * bergantung zona waktu perangkat yang membacanya.
 */
object HitungHari {

    private const val MILIS_SEHARI = 24L * 60 * 60 * 1000

    /**
     * Selisih hari antara [sekarang] dan [jatuhTempo]: negatif bila sudah
     * terlewat, 0 bila hari ini, 1 bila besok.
     */
    fun selisih(
        jatuhTempo: Long,
        sekarang: Long,
        zona: TimeZone = TimeZone.getDefault(),
    ): Int {
        if (jatuhTempo <= 0L) return 0
        val hariIni = tengahMalam(sekarang, zona)
        val hariJatuhTempo = tengahMalam(jatuhTempo, zona)
        return ((hariJatuhTempo - hariIni) / MILIS_SEHARI).toInt()
    }

    /** Teks hitungan hari yang ditampilkan di widget. */
    fun teks(sisaHari: Int): String = when {
        sisaHari < 0 -> "Terlewat ${-sisaHari} hari"
        sisaHari == 0 -> "Hari ini"
        sisaHari == 1 -> "Besok"
        else -> "$sisaHari hari lagi"
    }

    /** Instant pukul 00:00 pada tanggal [millis] menurut [zona]. */
    private fun tengahMalam(millis: Long, zona: TimeZone): Long {
        val kalender = Calendar.getInstance(zona).apply { timeInMillis = millis }
        kalender.set(Calendar.HOUR_OF_DAY, 0)
        kalender.set(Calendar.MINUTE, 0)
        kalender.set(Calendar.SECOND, 0)
        kalender.set(Calendar.MILLISECOND, 0)
        return kalender.timeInMillis
    }
}
