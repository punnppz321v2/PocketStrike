allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // llama_flutter_android injects its own buildscript classpath with KGP 2.1.0
    // and AGP 8.9.1, which conflicts with the app's built-in Kotlin 2.3.20 / AGP
    // 9.0.1 and corrupts :app:compileReleaseKotlin. Align buildscript classpath
    // resolution so a single KGP/AGP version wins on every project's classpath.
    buildscript {
        configurations.classpath {
            resolutionStrategy.eachDependency {
                if (requested.group == "org.jetbrains.kotlin" && requested.name == "kotlin-gradle-plugin") {
                    useVersion("2.3.20")
                }
                if (requested.group == "com.android.tools.build" && requested.name == "gradle") {
                    useVersion("9.0.1")
                }
            }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
