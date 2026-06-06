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

subprojects {
    val configureAndroid = {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val setCompileSdk = android.javaClass.getMethod("setCompileSdk", java.lang.Integer::class.java)
                setCompileSdk.invoke(android, 36)
            } catch (e: Exception) {
                try {
                    val compileSdkVersion = android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                    compileSdkVersion.invoke(android, 36)
                } catch (e2: Exception) {}
            }
        }
    }
    if (state.executed) {
        configureAndroid()
    } else {
        afterEvaluate {
            configureAndroid()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    tasks.configureEach {
        if (name.contains("compile", ignoreCase = true) && name.contains("Kotlin", ignoreCase = true)) {
            try {
                val getKotlinOptions = this.javaClass.getMethod("getKotlinOptions")
                val kotlinOptions = getKotlinOptions.invoke(this)
                val setLanguageVersion = kotlinOptions.javaClass.getMethod("setLanguageVersion", String::class.java)
                val setApiVersion = kotlinOptions.javaClass.getMethod("setApiVersion", String::class.java)
                setLanguageVersion.invoke(kotlinOptions, "1.8")
                setApiVersion.invoke(kotlinOptions, "1.8")
                logger.info("Dynamically set Kotlin languageVersion and apiVersion to 1.8 for task: $name")
            } catch (e: Exception) {
                // Ignore tasks that do not expose kotlinOptions
            }
        }
    }
}
