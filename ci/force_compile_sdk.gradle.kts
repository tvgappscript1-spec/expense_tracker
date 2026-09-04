
// ============================================================================
// Ep compileSdk = 36 cho MOI module con (gom plugin file_picker...).
// File nay do CI noi vao cuoi android/build.gradle.kts truoc khi build.
// Ly do: loi "requires compile against version 36" den tu PLUGIN (file_picker),
// khong phai tu app; sua rieng app khong du, phai ap cho tat ca subproject.
// compileSdk chi anh huong luc bien dich, khong doi runtime/thiet bi cai duoc.
// ============================================================================
subprojects {
    afterEvaluate {
        val androidExt = project.extensions.findByName("android")
        if (androidExt != null) {
            try {
                val method = androidExt.javaClass.getMethod(
                    "compileSdkVersion", Int::class.javaPrimitiveType
                )
                method.invoke(androidExt, 36)
            } catch (e: Exception) {
                // Module khong phai Android -> bo qua.
            }
        }
    }
}
