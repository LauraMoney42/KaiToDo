import React, { useState, useEffect, useRef } from 'react';
import { StatusBar } from 'expo-status-bar';
import { Platform, StyleSheet, Text, View, TextInput, KeyboardAvoidingView, TouchableOpacity, ScrollView } from 'react-native';
import Task from './components/Task';
import LottieView from 'lottie-react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';



export default function App() {
  const [task, setTask] = useState();
  const [taskItems, setTaskItems] = useState([]);
  const [showConfetti, setShowConfetti] = useState(false);
  const confettiRef = useRef(null);

  function triggerConfetti() {
    confettiRef.current?.reset(); // Reset the animation
    confettiRef.current?.play(0); // Start the animation from the beginning
  }

  const handleAddTask = () => {
    setTaskItems([...taskItems, task]);
    setTask(null);
  }

  const completeTask = (index) => {
    let itemsCopy = [...taskItems];
    itemsCopy.splice(index, 1);
    setTaskItems(itemsCopy);
  }

  return (
    <View style={styles.container}>
      <View style={styles.contentContainer}>
        <View style={styles.tasksWrapper}>
          <Text style={styles.sectionTitle}>To Do</Text>
        </View>

        {/*Today's Tasks */}
        <ScrollView style={styles.scrollView}>
          <View style={styles.tasksWrapper}>
            <View style={styles.items}>
              {/*This is where tasks go*/}
              {taskItems.map((item, index) => {
                return (
                  <TouchableOpacity key={index} onPress={() => { completeTask(index); triggerConfetti(); }}>
                    <Task text={item} />
                  </TouchableOpacity>
                )
              })}
            </View>
          </View>
        </ScrollView>

        {/* Write a Task */}
        <KeyboardAvoidingView
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
          style={styles.writeTaskWrapper}
        >
          <TextInput
            style={styles.input}
            placeholder={'Write a task'}
            value={task}
            onChangeText={text => setTask(text)}
          />
          <TouchableOpacity onPress={handleAddTask}>
            <View style={styles.addWrapper}>
              <Text style={styles.addText}>+</Text>
            </View>
          </TouchableOpacity>
        </KeyboardAvoidingView>
      </View>

      {/* Confetti Animation */}
      <LottieView
        ref={confettiRef}
        source={require('./assets/confetti.json')}
        autoPlay={false}
        loop={false}
        style={styles.lottie}
        resizeMode='center'
        onAnimationFinish={() => setShowConfetti(false)} // Hide the animation after it finishes
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FFF',
    position: 'relative',  // Added position relative to container
  },
  contentContainer: {
    flex: 1,  // Ensures the main content container takes up the full height
  },
  sectionTitle: {
    fontSize: 40,
    textAlign: 'center',
    fontWeight: 'bold',
    paddingTop: 50,
    color: '#000',
  },
  scrollView: {
    marginHorizontal: 20,
    paddingBottom: 100,
  },
  tasksWrapper: {
    paddingTop: 10,
    paddingHorizontal: 20,
    opacity: 0.80,
  },
  items: {
    marginTop: 30,
  },
  writeTaskWrapper: {
    position: 'absolute',
    bottom: 60,
    width: '100%',
    flexDirection: 'row',
    justifyContent: 'space-around',
    alignItems: 'center',
  },
  input: {
    paddingVertical: 15,
    paddingHorizontal: 15,
    backgroundColor: '#FFF',
    borderRadius: 60,
    borderColor: '#C0C0C0',
    borderWidth: 1,
    width: 250,
    opacity: 0.65,
  },
  addWrapper: {
    width: 60,
    height: 60,
    backgroundColor: '#7161EF',
    borderRadius: 60,
    justifyContent: 'center',
    alignItems: 'center',
    borderColor: '#C0C0C0',
    borderWidth: 1,
    opacity: 0.70,
  },
  addText: {
    fontSize: 40,
    color: '#FFF',
    justifyContent: 'center',
    alignItems: 'center',
  },
  lottie: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    width: '100%',
    height: '100%',
    zIndex: 1000,
    pointerEvents: 'none',
  },
});

