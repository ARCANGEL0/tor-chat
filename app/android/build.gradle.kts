allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Some plugins (e.g. flutter_plugin_android_lifecycle via file_picker) now
// require compileSdk 36, while Flutter's per-plugin default is lower. Force
// every Android module in the build to compile against 36.
subprojects {
    fun forceCompileSdk() {
        extensions.findByName("android")?.let { ext ->
            when (ext) {
                is com.android.build.api.dsl.LibraryExtension -> ext.compileSdk = 36
                is com.android.build.api.dsl.ApplicationExtension -> ext.compileSdk = 36
            }
        }
    }
    if (state.executed) forceCompileSdk() else afterEvaluate { forceCompileSdk() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
