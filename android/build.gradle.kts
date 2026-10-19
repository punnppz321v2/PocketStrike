allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // llama_flutter_android injects its own buildscript classpath with KGP 2.1.0,
    // which conflicts with the app's built-in Kotlin 2.3.20 and corrupts
    // :app:compileReleaseKotlin (unresolved references / "overrides nothing").
    // Force a single KGP version on every project's buildscript classpath so the
    // compiler sees one consistent Kotlin plugin. AGP is intentionally NOT
    // forced here, because llama_flutter_android's legacy android{} DSL would
    // hard-fail under AGP 9.0.1's newDsl.
    buildscript {
        configurations.classpath {
            resolutionStrategy.eachDependency {
                if (requested.group == "org.jetbrains.kotlin" && requested.name == "kotlin-gradle-plugin") {
                    useVersion("2.3.20")
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
