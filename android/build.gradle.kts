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

// Some plugin AARs (e.g. file_picker) pin an older compileSdk than the
// flutter_plugin_android_lifecycle version other plugins pull in transitively.
// Force every Android library subproject to compile against the same SDK as
// the app itself so AAR metadata checks don't fail.
subprojects {
    if (project.name != "app") {
        afterEvaluate {
            extensions.findByName("android")?.let { ext ->
                val android = ext as com.android.build.gradle.BaseExtension
                android.compileSdkVersion(36)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
