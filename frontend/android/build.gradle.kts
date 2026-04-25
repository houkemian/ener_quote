allprojects {
    repositories {

                google()
        mavenCentral()
      //  maven { url = uri("https://maven.aliyun.com/repository/google") }
      //  maven { url = uri("https://maven.aliyun.com/repository/public") }
      //  maven { url = uri("https://mirrors.tencent.com/nexus/repository/maven-public/") }

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
    
    // 🌟 终极强权指令：强制接管所有第三方 Flutter 插件的下载源 (纯正 Kotlin 版)
    buildscript {
        repositories {

                        google()
            mavenCentral()
        //    maven { url = uri("https://maven.aliyun.com/repository/google") }
        //    maven { url = uri("https://maven.aliyun.com/repository/public") }
        //    maven { url = uri("https://mirrors.tencent.com/nexus/repository/maven-public/") }

        }
    }
    repositories {
                google()
        mavenCentral()
        //maven { url = uri("https://maven.aliyun.com/repository/google") }
        //maven { url = uri("https://maven.aliyun.com/repository/public") }
        //maven { url = uri("https://mirrors.tencent.com/nexus/repository/maven-public/") }

    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}