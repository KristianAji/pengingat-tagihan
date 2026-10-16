package com.pengingattagihan.app.widget

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

/**
 * Tes hitungan hari widget.
 *
 * Zona waktu dikunci (WITA, UTC+8 — sama seperti perangkat uji) supaya
 * hasilnya tidak berubah mengikuti zona mesin yang menjalankan tes. Ini
 * penting karena tanggal jatuh tempo disimpan sebagai instant absolut.
 */
class HitungHariTest {

    private val zona: TimeZone = TimeZone.getTimeZone("Asia/Makassar")

    /** Instant pukul [jam] pada tanggal tertentu, menurut [zona]. */
    private fun waktu(
        tahun: Int,
        bulan: Int,
        tanggal: Int,
        jam: Int = 0,
        menit: Int = 0,
    ): Long = Calendar.getInstance(zona).apply {
        clear()
        set(tahun, bulan - 1, tanggal, jam, menit, 0)
    }.timeInMillis

    @Test
    fun `hari yang sama terbaca nol`() {
        val sekarang = waktu(2026, 10, 16, jam = 9)
        assertEquals(0, HitungHari.selisih(waktu(2026, 10, 16), sekarang, zona))
    }

    @Test
    fun `jatuh tempo nanti malam tetap terbaca hari ini`() {
        // Inti aturan "per tanggal": selisih 23:59 hari ini bukan 1 hari.
        val sekarang = waktu(2026, 10, 16, jam = 0)
        val malamIni = waktu(2026, 10, 16, jam = 23, menit = 59)
        assertEquals(0, HitungHari.selisih(malamIni, sekarang, zona))
    }

    @Test
    fun `besok dan beberapa hari ke depan`() {
        val sekarang = waktu(2026, 10, 16, jam = 9)
        assertEquals(1, HitungHari.selisih(waktu(2026, 10, 17), sekarang, zona))
        assertEquals(3, HitungHari.selisih(waktu(2026, 10, 19), sekarang, zona))
        assertEquals(7, HitungHari.selisih(waktu(2026, 10, 23), sekarang, zona))
    }

    @Test
    fun `tanggal yang sudah lewat bernilai negatif`() {
        val sekarang = waktu(2026, 10, 16, jam = 9)
        assertEquals(-1, HitungHari.selisih(waktu(2026, 10, 15), sekarang, zona))
        assertEquals(-5, HitungHari.selisih(waktu(2026, 10, 11), sekarang, zona))
    }

    @Test
    fun `menyeberangi pergantian bulan dan tahun`() {
        assertEquals(
            3,
            HitungHari.selisih(
                waktu(2026, 11, 2),
                waktu(2026, 10, 30, jam = 20),
                zona,
            ),
        )
        assertEquals(
            2,
            HitungHari.selisih(
                waktu(2027, 1, 1),
                waktu(2026, 12, 30, jam = 23),
                zona,
            ),
        )
    }

    @Test
    fun `data jatuh tempo kosong tidak dianggap terlewat`() {
        // 0 = data rusak/tidak ada; jangan sampai muncul "Terlewat 20000 hari".
        assertEquals(0, HitungHari.selisih(0L, waktu(2026, 10, 16, jam = 9), zona))
    }

    @Test
    fun `teks hitungan hari`() {
        assertEquals("Hari ini", HitungHari.teks(0))
        assertEquals("Besok", HitungHari.teks(1))
        assertEquals("5 hari lagi", HitungHari.teks(5))
        assertEquals("Terlewat 1 hari", HitungHari.teks(-1))
        assertEquals("Terlewat 12 hari", HitungHari.teks(-12))
    }
}
