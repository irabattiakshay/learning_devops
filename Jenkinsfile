pipeline{

    agent any
    // here any = keyword given by jenkins
    // here any = any available server where jenkisn can run the pipeline
    // rightnow the available server the ec2 machien where jenkisn is installed
    // so any = current machine

    tools{
        maven 'mymaven'
    }
    // here mymaven = version of the maven that we configured in tools section of Jenkins

    stages{
        stage('Clone the Repo'){
            steps{
                git 'https://github.com/irabattiakshay/DevOpsCodeDemo.git'
                // here git fucntion assumes branch is master
            }
        }
        stage('Compile the code'){
            steps{
                sh 'mvn compile'
                // if using windows give:  bat 'mvn compile'
            }
        }
        stage('Test the code'){
            steps{
                sh 'mvn test'
                // if using windows give:  bat 'mvn test'
            }
        }
        stage('Build the code'){
            steps{
                sh 'mvn package'
                // if using windows give:  bat 'mvn package'
            }
        }
    }
}