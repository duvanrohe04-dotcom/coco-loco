import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma de release: se lee de android/key.properties (no se sube al repositorio).
// Si el archivo no existe, el release se firma con la clave de debug para poder probarlo.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "com.cocoloco.game"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.cocoloco.game"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Salen de pubspec.yaml: version: 1.0.0+1  ->  versionName 1.0.0, versionCode 1
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Un solo APK para todos los celulares: solo ARM de 32 y 64 bits (ningún teléfono usa x86).
    // Quita librerías x86 sueltas que traen algunos plugins y que harían creer que hay soporte x86.
    // Para probar en el emulador (x86): flutter build apk --target-platform android-x64 --android-project-arg=keepX86=true
    if (!project.hasProperty("keepX86")) {
        packaging {
            jniLibs {
                excludes += setOf("lib/x86/**", "lib/x86_64/**")
            }
        }
    }

    signingConfigs {
        if (keystoreProperties.containsKey("storeFile")) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
            // Sin reducción de código (R8): no se pudo probar en un teléfono real y un plugin recortado
            // por error provoca pantallas en blanco. El tamaño casi no cambia (lo grande es el motor).
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
