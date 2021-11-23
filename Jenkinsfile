// =============================================================================
// Jenkinsfile -- Jenkins build pipeline definition
//
// Copyright (C) 2021 Kayisoft, Inc.
//
// Author: Mohammad Matini <mohammad.matini@outlook.com>
// Maintainer: Mohammad Matini <mohammad.matini@outlook.com>
//
// Description: Defines Jenkins build pipeline for Kayicoy.
//
// This file is part of Kayicoy.
//
// Kayicoy is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Kayicoy is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Kayicoy. If not, see <https://www.gnu.org/licenses/>.

pipeline {
  agent {
    kubernetes {
      label  "docker-${UUID.randomUUID().toString()}"
      defaultContainer 'docker'
      inheritFrom 'docker'
    }
  }
  stages {
    stage('build') {
      steps {
        container('docker') {
          script {
            checkout scm
            docker.withRegistry('http://127.0.0.1:34776', 'rancher-docker-registry') {
              def customImage = docker.build("connected/kayicoy:${GIT_COMMIT.take(7)}")
              customImage.push()
              if (GIT_BRANCH == 'master') {
                customImage.push('latest')
              } else if (GIT_BRANCH) {
                customImage.push(GIT_BRANCH.replace('/', '_'))
              } else if (GIT_TAG) {
                customImage.push(GIT_TAG)
              }
            }
          }
        }
      }
    }
  }
}
