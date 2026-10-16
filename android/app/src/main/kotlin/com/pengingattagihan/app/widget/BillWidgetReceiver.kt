package com.pengingattagihan.app.widget

import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

/**
 * Titik masuk widget dari sisi Android.
 *
 * Induknya dari plugin home_widget: dialah yang menyambungkan permintaan
 * "gambar ulang" dari Flutter (HomeWidget.updateWidget) ke [BillWidget].
 * Nama kelas ini dipakai sisi Dart — lihat WidgetService._receiverClass.
 */
class BillWidgetReceiver : HomeWidgetGlanceWidgetReceiver<BillWidget>() {
    override val glanceAppWidget = BillWidget()
}
