import React, {useState} from 'react';
import { StatusBar } from 'expo-status-bar';
import { Platform, StyleSheet, Text, View, TextInput, Keyboard, KeyboardAvoidingView, TouchableOpacity, ScrollView } from 'react-native';
import Task from './components/Task';


export default function App() {
  const [task, setTask] = useState();
  const [taskItems, setTaskItems] = useState([]);

  const handleAddTask = ()  => {
    Keyboard.dismiss();
    {/* appends new task*/}
    setTaskItems([...taskItems, task])
    {/*clears text entered*/}
    setTask(null);
  }

  const completeTask = (index) => {
    let itemsCopy = [...taskItems];
    itemsCopy.splice(index, 1);
    setTaskItems(itemsCopy);
  } 

  return (
    <View style={styles.container}>

<View style={styles.tasksWrapper}> 
<Text style={styles.sectionTitle}>Kai To Do</Text>
</View>


  {/*Today's Tasks */}
  <ScrollView style={styles.scrollView}>
  <View style={styles.tasksWrapper}>
    
    
  <View style={styles.items}> 
    {/*This is where tasks go*/}
    {
      taskItems.map((item, index) => {
        return (
        <TouchableOpacity key={index} onPress={() => completeTask(index)}>
          <Task text={item}  />
        </TouchableOpacity>
        )
      })
    }
    {/*  <Task text={'Task 1'} />
      <Task text={'Task 2'} />
  <Task text={'Task 3'} /> */}
    </View>
    

  </View>
  </ScrollView>
  {/* Write Task */}
  <KeyboardAvoidingView
  behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
  style={styles.writeTaskWrapper}
    >
      {/* Where user types in task and is visible at bottom*/}
      <TextInput style={styles.input} placeholder={'Write a task'} value ={task} onChangeText={text => setTask(text)}/>
       
       {/* Plus +*/}
        <TouchableOpacity onPress={() => handleAddTask()}>
      <View style={styles.addWrapper}>
        <Text style={styles.addText}>+</Text>
      </View>
    </TouchableOpacity>
  </KeyboardAvoidingView>


    </View>

  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FFF',
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
    opacity: .80,
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
    opacity: .65,
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
    opacity: .70,
  },
  addText: {
    fontSize: 40,
    color: '#FFF',
    justifyContent: 'center',
    alignItems: 'center',
}
});