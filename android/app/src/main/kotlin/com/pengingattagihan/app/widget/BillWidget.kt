package com.pengingattagihan.app.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
// defaultWeight() TIDAK diimpor: ia anggota RowScope/ColumnScope, jadi
// otomatis tersedia di dalam blok Row { }.
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import org.json.JSONObject

/**
 * Fitur 4 (tahap 1): widget Home Screen yang menampilkan tagihan terdekat.
 *
 * Tampil saja — belum ada tombol aksi. Datanya datang dari sisi Flutter
 * (lib/services/widget_service.dart) lewat penyimpanan milik plugin
 * home_widget; widget ini hanya menggambar ulang isinya.
 *
 * Hitungan harinya sengaja dihitung DI SINI, bukan dikirim sebagai teks dari
 * Dart: widget tetap terlihat berhari-hari tanpa aplikasi dibuka, jadi teks
 * "3 hari lagi" yang dikirim sekali akan berbohong. Yang dikirim Dart adalah
 * tanggal jatuh temponya (epoch ms), lalu di sini diubah jadi teks sesuai
 * hari ini.
 */
class BillWidget : GlanceAppWidget() {

    /** Wajib: memberi tahu plugin cara membaca data yang dikirim Flutter. */
    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent { WidgetContent(currentState()) }
    }

    @Composable
    private fun WidgetContent(state: HomeWidgetGlanceState) {
        val mentah = state.preferences.getString(KUNCI_TAGIHAN, null)
        val daftar = bacaTagihan(mentah)

        Column(
            modifier = GlanceModifier
                .background(WARNA_LATAR)
                .padding(12.dp)
                .fillMaxSize(),
        ) {
            Text(
                text = "Tagihan Terdekat",
                style = TextStyle(
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    color = ColorProvider(WARNA_TEKS),
                ),
            )

            if (daftar.isEmpty()) {
                Spacer(GlanceModifier.height(6.dp))
                Text(
                    // null = Flutter belum pernah mengirim data (widget dipasang
                    // sebelum aplikasi dibuka).
                    text = if (mentah == null) {
                        "Buka aplikasi untuk menyiapkan widget."
                    } else {
                        "Belum ada tagihan."
                    },
                    style = TextStyle(
                        fontSize = 12.sp,
                        color = ColorProvider(WARNA_REDUP),
                    ),
                )
                return@Column
            }

            daftar.forEach { BarisTagihan(it) }
        }
    }

    @Composable
    private fun BarisTagihan(tagihan: Tagihan) {
        val sisaHari = HitungHari.selisih(
            jatuhTempo = tagihan.jatuhTempo,
            sekarang = System.currentTimeMillis(),
        )

        // Merah bila sudah telat, oranye bila tinggal <= 3 hari.
        val warnaHitung = when {
            sisaHari < 0 -> WARNA_MERAH
            sisaHari <= 3 -> WARNA_ORANYE
            else -> WARNA_REDUP
        }

        Row(
            modifier = GlanceModifier
                .fillMaxWidth()
                .padding(vertical = 6.dp),
        ) {
            Column(modifier = GlanceModifier.defaultWeight()) {
                Text(
                    text = tagihan.nama,
                    maxLines = 1,
                    style = TextStyle(
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = ColorProvider(WARNA_TEKS),
                    ),
                )
                Text(
                    text = HitungHari.teks(sisaHari),
                    style = TextStyle(
                        fontSize = 11.sp,
                        color = ColorProvider(warnaHitung),
                    ),
                )
            }
            Text(
                text = tagihan.nominal,
                maxLines = 1,
                style = TextStyle(
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = ColorProvider(WARNA_TEKS),
                ),
            )
        }
    }

    // ── Pembacaan data ──

    private data class Tagihan(
        val nama: String,
        val nominal: String,
        val jatuhTempo: Long,
    )

    /** Baca JSON dari Dart. Data rusak/kosong sengaja tidak melempar. */
    private fun bacaTagihan(mentah: String?): List<Tagihan> {
        if (mentah.isNullOrBlank()) return emptyList()
        return try {
            val items = JSONObject(mentah).optJSONArray("items") ?: return emptyList()
            (0 until items.length()).mapNotNull { i ->
                val o = items.optJSONObject(i) ?: return@mapNotNull null
                Tagihan(
                    nama = o.optString("nama", "-"),
                    nominal = o.optString("nominal", ""),
                    jatuhTempo = o.optLong("jatuhTempo", 0L),
                )
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private companion object {
        const val KUNCI_TAGIHAN = "tagihan_json"

        // Warna disamakan dengan AppColors di lib/theme/app_theme.dart.
        val WARNA_LATAR = Color(0xFFF4F6FB)
        val WARNA_TEKS = Color(0xFF212529)
        val WARNA_REDUP = Color(0xFF868E96)
        val WARNA_ORANYE = Color(0xFFF08C00)
        val WARNA_MERAH = Color(0xFFFA5252)
    }
}
